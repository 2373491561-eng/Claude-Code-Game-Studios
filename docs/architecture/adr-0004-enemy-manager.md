# ADR-0004: Centralized Enemy Manager

## Status
Accepted

## Date
2026-05-08

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — `MultiMeshInstance2D`, arrays, `Sprite2D` all in training data |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | `duplicate_deep()` (4.5+) for VFX pool resource cloning |
| **Verification Required** | Benchmark 40-instance MultiMesh vs 40 Sprite2D nodes at 240fps |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (physics 60Hz + separation grid) |
| **Enables** | ADR-0005 (event architecture), ADR-0010 (skill_2 pierce via `check_bullet_hit()`), ADR-0011 (flow-field pathfinding) |
| **Blocks** | None directly |
| **Ordering Note** | Must be implemented before any enemy behavior code |

## Context

### Problem Statement
Godot 的惯用模式是每个敌人一个 `CharacterBody2D` 节点 + 独立的 `_process()` / `_physics_process()`。这在 10-20 个敌人时工作正常。但在峰值 53 个敌人 + 240fps 目标下，53 个节点 × 每个独立的 `_process` = 53 个函数调用/帧 + 53 个物理体/步。函数调用开销可控，但数据布局差（每个节点的数据分散在堆上 → 缓存未命中），且物理场景树有 53 个体进行碰撞检测。

敌人 GDD 明确要求"集中式敌人管理器：所有数据存于数组，统一 `_process` 更新"和"禁止每个敌人独立运行 `_process()`"。此 ADR 定义实现架构。

### Constraints
- 峰值 53 敌人（40 小/10 中/3 大）
- 240fps 渲染 / 60Hz 物理（ADR-0003）
- 3 种状态机类型（小/中/大）
- 渲染：小型用 MultiMesh，中/大型用 Sprite2D
- 碰撞检测：手动距离检测（不依赖物理体碰撞）

### Requirements
- 所有敌人 AI 在一个批处理循环中更新（非每节点 `_process`）
- 内存布局对缓存友好
- 死亡时 VFX 触发不受物理体移除影响
- 支持流场寻路（待 ADR-0011 确定）

## Decision

**采用 Struct-of-Arrays 集中式敌人管理器。所有敌人数据存储在并行数组中，AI 更新在一个批处理循环中完成。渲染根据敌人数量分层——小型用 MultiMeshInstance2D（40 实例），中型和大型用独立 Sprite2D。**

```gdscript
class_name EnemyManager extends Node2D

# Struct-of-Arrays: 每个属性是独立数组，索引对应同一个敌人
var _type: Array[int]           # EnemyType enum (SMALL=0, MEDIUM=1, LARGE=2)
var _state: Array[int]           # EnemyState enum
var _hp: Array[int]
var _max_hp: Array[int]
var _positions: Array[Vector2]
var _velocities: Array[Vector2]
var _timers: Array[float]        # 通用计时器（冷却/前摇/死亡）
var _active_count: int = 0

# 渲染
var _small_multimesh: MultiMeshInstance2D  # 40 实例，1 次绘制
var _medium_sprites: Array[Sprite2D]        # 10 个独立 Sprite2D
var _large_sprites: Array[Sprite2D]         # 3 个独立 Sprite2D

func _physics_process(_delta: float) -> void:
    var now = Time.get_ticks_msec()
    for i in range(_active_count):
        match _type[i]:
            EnemyType.SMALL:  _update_small(i, now)
            EnemyType.MEDIUM: _update_medium(i, now)
            EnemyType.LARGE:  _update_large(i, now)
    _update_separation_grid()  # 空间哈希（ADR-0003）
    _sync_rendering()

func _kill_enemy(i: int) -> void:
    _state[i] = EnemyState.DEAD
    _vfx_pool.spawn_death_particles(_type[i], _positions[i])
    # 标记移除——物理体移除延后（5-10/帧）
    _pending_removal.append(i)

func _process_removal_queue() -> void:
    # 每帧至多移除 10 个，避免物理服务器重载
    for _n in range(min(10, _pending_removal.size())):
        _remove_slot(_pending_removal.pop_front())
```

### Rendering Architecture

| 敌人类型 | 渲染方式 | 原因 |
|---------|---------|------|
| 小型 (40) | `MultiMeshInstance2D` | 1 次绘制调用替代 40 个 Sprite2D。死亡时设置实例 scale=0 隐藏 |
| 中型 (10) | 独立 `Sprite2D` (对象池) | 10 实例时 MultiMesh 的 per-instance shader 复杂度不划算 |
| 大型 (3) | 独立 `Sprite2D` (对象池) | 大量独特性（前摇动画、死亡多阶段）需要独立控制 |

### Collision Detection Strategy

不使用 `CharacterBody2D` 碰撞体——用手动距离检测：

```gdscript
# 玩家接触伤害检测（O(N)，N=53）
func _check_player_contact(player_pos: Vector2, player_radius: float) -> int:
    for i in range(_active_count):
        if _state[i] in [EnemyState.DEAD, EnemyState.SPAWNING]:
            continue
        var dist = _positions[i].distance_to(player_pos)
        if dist < player_radius + _radius[_type[i]]:
            return i  # 返回第一个接触的敌人索引
    return -1

# 子弹命中检测（O(N)，N=53）
func _check_bullet_hit(origin: Vector2, direction: Vector2, max_dist: float) -> Dictionary:
    var nearest_dist = max_dist
    var nearest_idx = -1
    for i in range(_active_count):
        if _state[i] == EnemyState.DEAD:
            continue
        var to_enemy = _positions[i] - origin
        var proj = to_enemy.dot(direction)
        if proj < 0 or proj > nearest_dist:
            continue
        var perp = (to_enemy - direction * proj).length()
        if perp < _radius[_type[i]] and proj < nearest_dist:
            nearest_dist = proj
            nearest_idx = i
    return {"index": nearest_idx, "position": origin + direction * nearest_dist}
```

O(N) 射线-圆相交测试替代 `PhysicsRayQueryParameters2D`——在 53 个敌人时比物理查询更快（避免 physics server 往返），且不依赖碰撞体节点。

## Alternatives Considered

### Alternative 1: Per-enemy Node（Godot 惯用模式）
- **Pros**: 符合 Godot 设计哲学，每个敌人自包含，场景树可视化
- **Cons**: 53 节点在场景树中 = 53 × `_process` 调用 + 53 物理体 = 物理 solver 负载。缓存局部性差
- **Rejection Reason**: 敌人 GDD 明确禁止。性能分析确认 53 节点模式在 240fps 不可行

### Alternative 2: ECS (Entity Component System)
- **Pros**: 最高性能，数据完全连续
- **Cons**: 无成熟的 Godot ECS 框架。需要自己实现或引入第三方库
- **Rejection Reason**: 53 敌人不需要 ECS 级别的优化。手动 Struct-of-Arrays 在可维护性和性能之间取得平衡

## Consequences

### Positive
- 数组连续 → 缓存友好 → AI 更新 <0.1ms/帧
- 手动碰撞检测避免 physics server 开销
- 死亡 VFX 与物理体移除解耦 → 30 连杀不会卡顿
- 添加新敌人类型只需加一个 `_update_` 函数

### Negative
- 放弃 Godot 场景树可视化——敌人不在场景树中，调试需要自定义工具
- 手动碰撞检测需要自己实现全部命中逻辑
- 中型和大型的独立 Sprite2D 池增加对象管理复杂度
- 新团队成员的学习曲线较高

### Risks
- **数组索引 bug**：索引错位导致错误的敌人被修改。缓解：添加 `assert(i < _active_count)` + debug 模式下验证数组长度一致
- **MultiMesh 死亡隐藏**：隐藏 MultiMesh 实例需要移到屏幕外或 scale=0——如果忘记恢复，会永久丢失实例。缓解：死亡状态机结束时有明确的实例回收逻辑

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| enemy-system.md | 集中式管理器 + 数组更新 | Struct-of-Arrays 架构 |
| enemy-system.md | MultiMesh 仅限小型敌人 | 中型/大型用 Sprite2D |
| enemy-system.md | 禁止每个敌人独立 _process() | 统一循环 _update_small/medium/large |
| enemy-system.md | 死亡碰撞体延后移除（5-10/帧） | `_pending_removal` 队列 |
| enemy-system.md | 手动射线-圆相交检测（O(N)） | `_check_bullet_hit()` |
| shooting-system.md | Hitscan 命中检测 | 手动检测替代 `intersect_ray()` |

## Performance Implications
- **CPU**: AI 更新 <0.1ms/帧（53 次循环，纯向量数学）。碰撞检测 <0.05ms
- **Memory**: ~4KB（53 敌人 × 8 个数组 × 8 字节 ≈ 3.4KB + 开销）
- **Draw Calls**: 1 (MultiMesh) + 10 (Medium Sprite2D) + 3 (Large Sprite2D) = 14 draws for enemies
- **Load Time**: 无影响

## Validation Criteria
- 53 敌人活跃：AI 更新 <0.1ms
- 技能 1 击杀 30 小兵：帧时间不超 4.17ms
- 连续 10 波敌人生成和死亡无内存泄漏
- MultiMesh 实例复用正确：无永久隐藏的实例
