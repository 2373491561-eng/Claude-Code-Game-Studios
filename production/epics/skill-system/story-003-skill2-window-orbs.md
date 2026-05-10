# Story 003: Skill_2 自动附加 + 充能球视觉

> **Epic**: skill-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/skill-system.md`
**Requirement**: `TR-skill-002`, `TR-skill-003`
**ADR Governing Implementation**: ADR-0010: Skill_2 Pierce, ADR-0005: Event/Signal Architecture
**ADR Decision Summary**: skill_2 窗口由极限闪避（充能≥1）打开，持续 500ms 真实时间。窗口内下一次攻击自动附加效果（伤害×2 + 穿透1）。再次极限闪避刷新窗口。充能球 Diegetic UI 四态：灰蓝(>80%) → 冷青(30-80%) → 电光蓝(0-30%) → 橙红脉动(=0%)。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: window 计时使用 `Time.get_ticks_msec()`；充能球 `z_index = -1`

---

## Acceptance Criteria

- [ ] `is_skill2_window_open(): bool` — 极限闪避（充能≥1）后 500ms 内返回 true
- [ ] 窗口内再次极限闪避 → 窗口刷新（重新计时 500ms）
- [ ] 窗口过期未消费 → 窗口关闭，后续攻击普通
- [ ] `consume_skill2()` — 射击系统调用，消费窗口并关闭
- [ ] 充能球四态视觉（灰蓝 >80% / 冷青 30-80% / 电光蓝 0-30% / 橙红脉动 0%）
- [ ] 每态之间的过渡 200ms 平滑插值
- [ ] 充能球 `z_index = -1`（渲染在角色之后）
- [ ] 充能球尺寸 12-14px 直径

---

## Implementation Notes

```gdscript
var _skill2_window_open_ms: int = 0
const SKILL2_WINDOW_MS = 500

func _on_perfect_dodge(charge_count: int) -> void:
    if charge_count >= 1:
        _skill2_window_open_ms = Time.get_ticks_msec()

func is_skill2_window_open() -> bool:
    return Time.get_ticks_msec() - _skill2_window_open_ms < SKILL2_WINDOW_MS

func consume_skill2() -> void:
    _skill2_window_open_ms = 0
```

充能球视觉直接复用 Diegetic UI 系统（不在本 Story 实现 UI 渲染，只暴露 `get_orb_state(): OrbState` 枚举）。

---

## QA Test Cases

- 窗口: 极限闪避后 → `is_skill2_window_open()` true → 500ms 后 false
- 刷新: 窗口 300ms 时再次极限闪避 → 窗口重新从 500ms 开始
- 消费: 攻击后 → `is_skill2_window_open()` false
- 充能球: 冷却比例 50% → 冷青色，1Hz 脉动

## Test Evidence: `tests/integration/skill/skill2_window_test.gd`
## Dependencies

- Depends on: Story 001, Story 002, DodgeSystem (perfect dodge), ShootingSystem (triggers consume)
- Unlocks: Diegetic UI epic
