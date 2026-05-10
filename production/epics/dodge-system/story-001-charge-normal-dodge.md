# Story 001: 闪避充能 + 普通闪避

> **Epic**: dodge-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/dodge-system.md`
**Requirement**: `TR-dodge-001`
**ADR Governing Implementation**: ADR-0007: Perfect Dodge Detection, ADR-0001: Real-Time Timing
**ADR Decision Summary**: 3 次充能，3s/次恢复。普通闪避消耗 1 次充能（充能≥1 时可用，充能=0 时不可用）。100px 位移 + 300ms 真实时间无敌帧。位移使用 `get_physics_process_delta_time()`（不受 time_scale 影响）。位移方向 = 当前移动方向 → 最后移动方向 → 瞄准反方向。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: 充能恢复使用 `_physics_process(delta)` 累加（不需要 `Time.get_ticks_msec()`，因为它是物理时间，非 gameplay 计时）；
  位移使用 `get_physics_process_delta_time()`；无敌帧使用 `Time.get_ticks_msec()`
- Forbidden: 不要使用 `delta` 参数计算位移（time_scale 会缩放 delta）

---

## Acceptance Criteria

- [ ] 初始充能 = 3，最大 = 3
- [ ] 充能恢复：3s 恢复 1 次（charge += delta/3.0），向下取整显示
- [ ] 充能恢复在闪避期间暂停（普通闪避暂停 300ms）
- [ ] 普通闪避条件：`floor(charge) >= 1`，消耗 1 次充能
- [ ] 充能=0 + 无攻击在 40px 内 → 按闪避无反应
- [ ] 闪避位移 100±5px，方向 = `normalize(move_axis)`；无移动输入时 = `last_move_dir`；从未移动 = 瞄准反方向
- [ ] 对角线方向归一化——100px 非 141px
- [ ] 位移使用 `move_and_collide(step)`（`step = dodge_speed * get_physics_process_delta_time()`），被障碍物截断时停在边缘
- [ ] 闪避期间碰撞层排除敌人层（穿透敌人），保留障碍物层
- [ ] 无敌帧 300ms 真实时间（`Time.get_ticks_msec()`），不受位移截断影响
- [ ] 闪避结束时若仍在敌人内部 → 螺旋搜索最近空位（最大 200px）

---

## Implementation Notes

- `get_physics_process_delta_time()` 返回不受 time_scale 影响的固定步长（~16.7ms at 60Hz）
- 充能恢复: `_charge += get_physics_process_delta_time() / CHARGE_REGEN_TIME`（仅非闪避期间）
- `is_invincible(): bool` 和 `get_charge_count(): int` 作为 DamageHealthSystem 的只读接口

## QA Test Cases

- AC1a: 充能=3，按住 W，按 Shift → 向上位移 100±5px，充能=2
- AC1c: 路径上有障碍物 <100px → 位移截断，无敌帧保持 300ms 完整
- AC2a: 充能=0，无攻击在 40px → 按 Shift 无反应
- AC6a: 闪避消耗充能 → 300ms 后充能恢复开始，3s 后充能+1

## Test Evidence: `tests/unit/dodge/charge_dodge_test.gd`
## Dependencies

- Depends on: InputSystem, PlayerMovement（`last_move_dir`, `position`）, EventBus
- Unlocks: Story 002 (perfect dodge), damage-health epic
