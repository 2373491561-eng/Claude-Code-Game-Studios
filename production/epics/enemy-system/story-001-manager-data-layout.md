# Story 001: 敌人管理器数据布局 + 渲染分层

> **Epic**: enemy-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/enemy-system.md`
**Requirement**: `TR-enemy-002`, `TR-enemy-003`
**ADR Governing Implementation**: ADR-0004: Centralized Enemy Manager
**ADR Decision Summary**: Struct-of-Arrays 数据布局（positions/velocities/states/timers/hp 并行数组）。MultiMeshInstance2D 渲染 40 小型敌人（1 draw call），Sprite2D 池渲染 10 中型 + 3 大型。手动碰撞检测（`check_bullet_hit`, `check_player_contact`）。死亡移除延迟 5-10/帧。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: Struct-of-arrays；MultiMesh for small；Sprite2D for medium/large；manual collision
- Forbidden: 不要 per-enemy `_process()`；不要 CharacterBody2D 碰撞体

---

## Acceptance Criteria

- [ ] EnemyManager 类：`class_name EnemyManager extends Node2D`
- [ ] 数组：`_type[]`, `_state[]`, `_hp[]`, `_max_hp[]`, `_positions[]`, `_velocities[]`, `_timers[]`，`_active_count` 跟踪活跃数
- [ ] `_small_multimesh: MultiMeshInstance2D` — 40 实例，1 绘制调用
- [ ] `_medium_sprites: Array[Sprite2D]` — 10 个（对象池）
- [ ] `_large_sprites: Array[Sprite2D]` — 3 个（对象池）
- [ ] `spawn_wave(config: WaveConfig)` 方法——交错生成（5-10/帧），100-200ms 淡入
- [ ] `check_bullet_hit(origin, direction, max_dist) -> Dictionary` — O(N) 射线-圆相交
- [ ] `check_player_contact(player_pos, radius) -> int` — O(N) 距离检测
- [ ] `get_all_attack_positions() -> Array[Vector2]` — 所有活跃敌人位置 + 在途子弹位置
- [ ] `apply_damage(index: int, amount: int)` — 扣血 + 检查死亡
- [ ] 死亡移除延迟：`_pending_removal` 队列，每帧移除 5-10 个

---

## Implementation Notes

```gdscript
func check_bullet_hit(origin: Vector2, direction: Vector2, max_dist: float) -> Dictionary:
    var nearest_dist = max_dist; var nearest_idx = -1
    for i in range(_active_count):
        if _state[i] == EnemyState.DEAD: continue
        var to_enemy = _positions[i] - origin
        var proj = to_enemy.dot(direction)
        if proj < 0 or proj > nearest_dist: continue
        var perp = (to_enemy - direction * proj).length()
        if perp < _radius[_type[i]] and proj < nearest_dist:
            nearest_dist = proj; nearest_idx = i
    return {"index": nearest_idx, "position": origin + direction * nearest_dist}
```

---

## QA Test Cases

- 数据结构：创建 53 个敌人 → `_active_count = 53`，所有数组长度一致
- `check_bullet_hit`：敌人在射线上 500px → 返回该敌人索引
- 死亡移除：技能 1 杀 30 → 每帧移除 5-10 个（检查 `_pending_removal` 队列消费）
- 内存：53 敌人 struct-of-arrays ≤ 4KB

## Test Evidence: `tests/unit/enemy/manager_data_test.gd`
## Dependencies

- Depends on: ADR-0004, ADR-0003 (60Hz physics)
- Unlocks: Story 002-004 (all enemy AI behaviors)
