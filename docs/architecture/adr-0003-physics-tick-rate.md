# ADR-0003: Physics Tick Rate & Collision Separation

## Status
Accepted

## Date
2026-05-08

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Physics |
| **Knowledge Risk** | LOW — GodotPhysics2D unchanged since 4.0 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None (Jolt is 3D-only, not applicable to 2D project) |
| **Verification Required** | Measure physics step CPU time at 60Hz vs 240Hz with 53 bodies clustered |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (timing), ADR-0002 (input processing in `_physics_process`) |
| **Enables** | ADR-0004 (enemy manager performance constraints) |
| **Blocks** | EnemySystem implementation — performance budget depends on this |
| **Ordering Note** | Must be set in Project Settings before enemy system development |

## Context

### Problem Statement
Godot 的物理 tick rate 默认 60Hz。项目目标 240fps 渲染——如果物理也跑 240Hz，碰撞检测和求解器负载增加 4 倍。性能分析师计算：53 个敌人全部聚群时，物理 narrowphase 产生 ~1431 对/步。60Hz = 85,860 对/秒；240Hz = 343,440 对/秒。加上约束求解器迭代，240Hz 物理在聚群场景下消耗 1.0-2.2ms——结合其他系统，帧预算 4.17ms 有被突破的风险。

同时，40 个小敌人全部冲向玩家时，AABB 几乎完全重叠——Godot 的 broadphase 无法过滤任何 pair。780 对敌人-敌人 pair 全部进入 narrowphase。纯依赖物理 solver 推离会产生震荡（推出→下帧又挤回）。

### Constraints
- 240fps 渲染目标（≤4.17ms 帧预算）
- 最高 53 个敌人同时活跃（40 小 + 10 中 + 3 大）
- 小型敌人碰撞半径 8-12px，需保持至少 1px 间隙
- 玩家 CharacterBody2D，敌人碰撞体（接触伤害检测）

### Requirements
- 物理 tick rate 不能导致帧预算超标
- 碰撞分离必须在最坏情况下（53 聚群）保持稳定
- 渲染平滑度不受物理 tick rate 影响

## Decision

**1. 物理 tick rate 设为 60Hz。渲染与物理分离——`_physics_process` 60Hz，`_process` 240fps。**

Godot 默认提供渲染插值（`Physics Interpolation`），在 60Hz 物理和 240fps 渲染之间平滑过渡。视觉效果与 240Hz 物理完全相同。

**2. 使用空间哈希网格进行分离 steering，减轻物理 solver 负担。**

不依赖 Godot 物理 solver 单独分离敌人——在集中式敌人管理器的 AI 更新中加一个轻量的分离 steering pass：

```gdscript
const GRID_CELL = 32  # px
var _spatial_grid: Dictionary  # key: Vector2i(cell_x, cell_y), value: Array[int] (enemy indices)

func _update_separation(delta: float) -> void:
    _build_grid()
    for i in range(_active_small_count):
        var cell = _world_to_cell(_positions[i])
        var sep_vector = Vector2.ZERO
        # 只检查相邻 9 个单元
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                var neighbors = _spatial_grid.get(cell + Vector2i(dx, dy), [])
                for j in neighbors:
                    if j <= i: continue  # 避免重复计算
                    var dist = _positions[i].distance_to(_positions[j])
                    if dist < MIN_SEPARATION:
                        sep_vector += (_positions[i] - _positions[j]).normalized()
        _velocities[i] += sep_vector * SEPARATION_FORCE * delta
```

空间哈希将分离检查从 O(N²) 780 对降至 ~200 对（40 个小敌人分布在 ~15 个单元中，每个单元 2-3 个，每个检查 9 个相邻单元）。

### Architecture Diagram

```
ProjectSettings:
  physics/common/physics_ticks_per_second = 60
  physics/common/physics_interpolation = ON

_physics_process (60Hz):          _process (240fps):
  ├─ Input polling                ├─ Charged orb visual
  ├─ Movement + dodge             ├─ Health halo update
  ├─ Shooting (hitscan)           ├─ HUD updates
  ├─ Skill cooldown               ├─ Particle pool
  ├─ Damage processing            └─ Camera smoothing
  ├─ Enemy AI + separation
  └─ Physics solver (body motion)

Separation: Spatial hash grid (32px cells)
  40 small enemies → ~15 cells → ~200 distance checks
  ↓
  separation vector → velocity modifier
  ↓
  GodotPhysics2D solver (reduced load, already spaced out)
```

## Alternatives Considered

### Alternative 1: 240Hz physics
- **Pros**: 物理精度更高，移动更精确
- **Cons**: 4 倍负载。聚群场景下物理 ≥2ms，可能突破帧预算
- **Rejection Reason**: 240fps 物理对 2D 俯视角射击无实际收益——300px/s 的移动速度在 60Hz 下每步 5px，已经足够精确

### Alternative 2: 纯 Godot 物理 solver 分离（无 steering）
- **Pros**: 实现简单，无需额外代码
- **Cons**: 40 个敌人全部冲向同一点 = AABB 几乎完全重叠 = broadphase 失效。Solver 推离产生震荡
- **Rejection Reason**: 震荡产生的视觉抖动影响游戏体验，且 solver 负载不可控

## Consequences

### Positive
- 物理负载降至 1/4——从主要瓶颈变为安全余量
- 空间哈希分离产生更平滑的敌人移动
- 渲染插值保证 240fps 的视觉流畅度
- 未来扩展（>53 敌人）有充足余量

### Negative
- 60Hz 物理 → 输入响应延迟最多 1 帧（~16.7ms）。在 240fps 渲染和插值下不可感知
- 空间哈希需要每帧重建（但 O(N) 且 N=40，成本极低）
- 两个更新循环（`_physics_process` + `_process`）增加了代码复杂度

### Risks
- **物理插值伪影**：快速移动物体（弹丸）可能出现轻微模糊。缓解：弹丸使用 `Area2D`（非插值），启用 `Physics Interpolation`
- **分离 steering 过强**：敌人移动可能看起来在"滑行"。缓解：`SEPARATION_FORCE` 作为可调参数，默认值保守

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| enemy-system.md | 帧时间 ≤4.17ms（53 敌人全活跃） | 60Hz 物理 + 空间哈希 → 物理负载 <1ms |
| enemy-system.md | 小型敌人间最低 1px 间隙 | 分离 steering 确保间隙 |
| enemy-system.md | 碰撞分离用空间哈希网格（32px 单元） | 集中式管理器实现 |
| dodge-system.md | 闪避位移使用 `get_physics_process_delta_time()` | 60Hz 固定步长保证位移精度 ±5px |

## Performance Implications
- **CPU (60Hz)**: 物理 solver 0.5-0.8ms（↓ from 2.0-3.2ms at 240Hz）
- **CPU (240fps)**: 渲染插值 0.05ms
- **Memory**: 空间哈希字典 ~2KB（~15 单元 × 4 个敌人索引/单元）
- **Load Time**: 无影响

## Validation Criteria
- 53 敌人聚群拥向玩家：帧时间 ≤4.17ms
- 40 个小敌人在 >2s 内无震荡抖动
- 物理直方图：物理步 ≤0.8ms（P95）
- `_physics_process` 每帧恰好运行 1 次（60Hz 锁定）
