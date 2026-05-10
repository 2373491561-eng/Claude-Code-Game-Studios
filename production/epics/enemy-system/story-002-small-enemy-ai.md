# Story 002: 小型敌人 AI + 空间哈希分离

> **Epic**: enemy-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/enemy-system.md`
**Requirement**: `TR-enemy-001`, `TR-enemy-004`, `TR-enemy-005`
**ADR Governing Implementation**: ADR-0004: Enemy Manager, ADR-0003: Physics 60Hz
**ADR Decision Summary**: 小型敌人直线冲向玩家（200px/s），接触伤害 1 点 → 200ms 受击冷却 → 推开 10-15px。空间哈希网格（32px 单元）分离 steering，每帧重建。检查相邻 9 单元而非 O(N²)。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: 空间哈希 32px 单元；`Time.get_ticks_msec()` 状态机计时；分离 force 加到 velocity
- Forbidden: 不要 O(N²) 全遍历分离检测

---

## Acceptance Criteria

- [ ] 小型敌人：16-24px 尺寸，HP=1，200px/s，碰撞半径 8-12px
- [ ] 追逐状态：直线冲向玩家位置
- [ ] 接触伤害：碰撞半径重叠 → 玩家受 1 点伤害 → 进入受击冷却 200ms
- [ ] 受击冷却：推开 10-15px，200ms 内不再次造成伤害，然后返回追逐
- [ ] 受伤：HP 减少 → 白帧闪烁 2 帧，继续当前状态
- [ ] 空间哈希：`GRID_CELL = 32`，每帧重建网格，每个敌人只查 9 个相邻单元
- [ ] 分离 steering：min_separation = 碰撞半径和 + 1px，分离力加到 velocity
- [ ] 40 小型敌人聚群时无震荡抖动（>2s 稳定）

---

## Implementation Notes

```gdscript
const GRID_CELL = 32
func _update_separation(delta: float) -> void:
    _build_grid()  # O(N)
    for i in range(_active_small_count):
        var cell = Vector2i(floor(_positions[i].x / GRID_CELL), floor(_positions[i].y / GRID_CELL))
        var sep = Vector2.ZERO
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                for j in _spatial_grid.get(cell + Vector2i(dx, dy), []):
                    if j >= i: continue
                    var dist = _positions[i].distance_to(_positions[j])
                    if dist < MIN_SEPARATION:
                        sep += (_positions[i] - _positions[j]).normalized()
        _velocities[i] += sep * SEPARATION_FORCE * delta
```

---

## QA Test Cases

- 追逐：小型敌人以 200±10px/s 冲向玩家
- 接触伤害：重叠 → 玩家 HP-1，敌人冷却 200ms
- 分离：40 小型聚群 → 最小间距 ≥1px，>2s 无震荡
- 性能：40 小型分离 <0.05ms

## Test Evidence: `tests/unit/enemy/small_ai_test.gd`
## Dependencies

- Depends on: Story 001 (EnemyManager data layout + collision methods)
- Unlocks: Story 003, Story 004
