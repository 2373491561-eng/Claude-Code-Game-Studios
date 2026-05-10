# ADR-0007: Perfect Dodge Detection

## Status
Accepted

## Date
2026-05-08

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Measure distance check time for 53 entities at 240fps |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (input processing), ADR-0004 (enemy manager) |
| **Enables** | Skill_2 auto-attach, Dodge healing |
| **Blocks** | DodgeSystem implementation |
| **Ordering Note** | Must be implemented before skill_2 and healing can work |

## Context

### Problem Statement
极限闪避是《裂隙反应》的核心机制——玩家在攻击进入 40px 范围内按下闪避 = 不消耗充能 + 时间缩放 + 回血 + 护盾 + 触发 skill_2。最初的设计只检测敌方**子弹**——但这意味着占屏幕 80% 威胁的小型虫群（接触伤害，无子弹）完全无法触发回血机制。伤害与血量 GDD v1 修订中已将检测范围扩展至所有攻击类型：子弹、接触敌人逼近、近战范围攻击。

从技术角度看，检测"任意敌方攻击在 40px 内"需要每个物理帧检查 53 个敌人的位置和攻击状态。距离检测本身便宜（向量长度），但需要明确的攻击来源定义。

### Constraints
- 53 敌人峰值（40 小/10 中/3 大）
- 40px 检测半径（欧几里得距离，中心到中心）
- 多目标在范围内 → 只触发 1 次极限闪避（最近的优先）
- 检测必须与闪避输入同帧完成（在 `_physics_process` 中，ADR-0002）

### Requirements
- 检测所有攻击类型：子弹位置、接触型敌人位置、近战攻击范围
- O(N) 复杂度（N ≤ 53 敌人 + ~27 在途子弹）
- 取最近攻击判定（多目标在范围内时）

## Decision

**在 DodgeSystem._physics_process() 中执行 O(N) 距离检查。查询 EnemyManager 获取所有活跃攻击位置（敌人位置 + 在途子弹位置），取最近的一个与 40px 比较。**

```gdscript
func _check_perfect_dodge(player_pos: Vector2) -> bool:
    var attacks = enemy_manager.get_all_attack_positions()
    # attacks: Array[Vector2] — 包含：
    #   - 所有活跃敌人的位置（接触型伤害在敌人位置发生）
    #   - 所有在途中型子弹的位置
    #   - 大型敌人的位置（近战 AoE 在 80px 范围，但检测以位置为中心）
    
    var nearest_dist = PERFECT_DISTANCE + 1.0  # 40px + epsilon
    for attack_pos in attacks:
        var dist = player_pos.distance_squared_to(attack_pos)
        if dist < nearest_dist * nearest_dist:
            nearest_dist = sqrt(dist)  # 仅在找到更近目标时才 sqrt
    
    return nearest_dist <= PERFECT_DISTANCE
```

### EnemyManager 接口

```gdscript
# EnemyManager 暴露的攻击位置数组
func get_all_attack_positions() -> Array[Vector2]:
    var positions: Array[Vector2] = []
    # 1. 所有活跃敌人的位置（接触伤害）
    for i in range(_active_count):
        if _state[i] != EnemyState.DEAD:
            positions.append(_positions[i])
    # 2. 所有在途中型子弹位置
    for bullet in _active_bullets:
        positions.append(bullet.global_position)
    return positions
```

### 攻击类型检测扩展

| 攻击类型 | 检测来源 | 检测时机 |
|---------|---------|---------|
| 小型接触伤害 | 敌人位置（碰撞半径 8-12px 内即接触） | 每物理帧 |
| 中型子弹 | 在途子弹 Area2D 位置 | 每物理帧 |
| 中型接触伤害 | 敌人位置（若玩家进入碰撞半径） | 每物理帧 |
| 大型近战 | 敌人位置 + 近战前摇激活标记 | 每物理帧 |
| 大型冲锋 | 敌人位置 + 冲锋激活标记 | 每物理帧 |

### 性能优化

使用 `distance_squared_to()` 避免不必要的 `sqrt()`。只在找到候选最近目标时才计算实际距离：

```gdscript
var nearest_dist_sq = PERFECT_DISTANCE * PERFECT_DISTANCE
var found = false
for pos in attacks:
    var dist_sq = player_pos.distance_squared_to(pos)
    if dist_sq < nearest_dist_sq:
        nearest_dist_sq = dist_sq
        found = true
return found
```

80 次距离平方检查（53 敌人 + 27 子弹）× 60Hz = 4,800 次/秒。每次 `distance_squared_to` 约 3 次浮点运算。总计 ~14,400 浮点运算/秒——可以忽略不计。

## Alternatives Considered

### Alternative 1: Area2D 触发器
- **Pros**: 使用 Godot 物理引擎，自动检测重叠
- **Cons**: 需要 40px 半径 `Area2D` 跟随玩家 + 所有攻击来源有碰撞体。物理引擎开销比手动距离检查高。`area_entered` 信号时序不确定
- **Rejection Reason**: 手动 O(N) 距离检查比物理查询更快，且结果在同一帧确定（无信号延迟）

### Alternative 2: 只检测子弹
- **Pros**: 概念简单，检测数量少（~27 而非 80）
- **Cons**: 最频繁的威胁（小型虫群接触伤害）无法触发完美闪避——玩家回血的唯一渠道对 80% 屏幕威胁失效
- **Rejection Reason**: 在伤害与血量 GDD v1 审查中已明确否决——导致结构性设计漏洞

## Consequences

### Positive
- 所有攻击类型统一处理——极限闪避对任何威胁都可触发
- O(N) 手动检测比物理引擎更快
- 距离平方优化避免不必要的 sqrt
- 取最近攻击的逻辑防止多目标同时触发

### Negative
- 检测数量从 ~27（仅子弹）增加到 ~80（所有攻击）
- EnemyManager 需要额外暴露 `get_all_attack_positions()` 接口
- 40px 阈值是全局常量——不同攻击类型不能有不同的检测半径

### Risks
- **误触发达成极限闪避**：40 个小敌人包围时，几乎必然有敌人在 40px 内。缓解：这正是设计意图——小型群聚是极限闪避的最佳时机
- **大型近战前摇期间位置不变**：大型在 400ms 前摇期间静止——玩家容易判断 "他不动了 = 我要闪避"。这是良性的

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| dodge-system.md | 极限闪避检测所有攻击类型在 40px 内 | O(N) 距离检查涵盖 5 种攻击类型 |
| damage-health.md | 极限闪避范围扩展至接触+子弹+近战 | 统一检测接口 |
| enemy-system.md | 暴露敌人攻击位置供闪避检测 | `get_all_attack_positions()` |
| skill-system.md | skill_2 自动附加触发 | 极限闪避成功后 500ms 窗口打开 |

## Performance Implications
- **CPU (60Hz)**: ~80 次 `distance_squared_to` ≈ 0.001ms/帧
- **Memory**: Array[Vector2] 临时分配 ~80 × 8 = 640 字节/帧。可用静态缓冲区消除分配
- **Load Time**: 无影响

## Validation Criteria
- 小型敌人距玩家 39px 时按闪避 → 极限闪避触发
- 中型子弹距玩家 39px 时按闪避 → 极限闪避触发
- 小型敌人距玩家 41px 时按闪避 → 普通闪避（非极限）
- 同帧 3 个攻击在 40px 内 → 取最近者，只触发 1 次极限闪避
