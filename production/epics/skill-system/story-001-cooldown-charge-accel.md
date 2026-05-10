# Story 001: 技能 1 冷却 + 充能加速

> **Epic**: skill-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/skill-system.md`
**Requirement**: `TR-skill-001`
**ADR Governing Implementation**: ADR-0001: Real-Time Timing Strategy
**ADR Decision Summary**: 技能 1 冷却 15s 真实时间（`Time.get_ticks_msec()`）。充能加速冷却：cd_speed = 1.0 + max(charge-1, 0) × 0.5。充能=3 → 2×速（等效 7.5s）。闪避缩减 CD（普通 -3s，极限 -8s，充能门控）。CD 缩减上限 60%（9s）。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: 冷却使用 `Time.get_ticks_msec()`；充能门控（charge≥1 才有 CD 缩减）；CD 缩减上限 60%

---

## Acceptance Criteria

- [ ] 技能 1 冷却 15s 真实时间（不受 time_scale 影响）
- [ ] 充能加速：charge=3 → cd_speed=2.0（15s 等效 7.5s）；charge=2 → ×1.5；charge=1 → ×1.0；charge=0 → ×1.0
- [ ] 冷却速度随充能实时更新（充能下降后 cd_speed 立即下降）
- [ ] 普通闪避（充能≥1）→ CD -3s（不少于 0）
- [ ] 极限闪避（充能≥1）→ CD -8s（不少于 0）
- [ ] 极限闪避（充能=0）→ 不缩短 CD
- [ ] CD 缩减上限 9s（60% × 15s），触及上限时充能球闪烁金色 100ms
- [ ] CD ≤ 0 → 技能就绪，不预载至下一次冷却
- [ ] `is_skill1_ready(): bool` 公共接口

---

## Implementation Notes

```gdscript
const BASE_CD = 15.0
const CD_CAP_RATIO = 0.6  # 60% max reduction per cycle

func _update_cooldown() -> void:
    var now = Time.get_ticks_msec()
    var elapsed = (now - _last_tick_ms) / 1000.0
    var cd_speed = 1.0 + max(dodge_system.get_charge_count() - 1, 0) * 0.5
    _cooldown_remaining -= elapsed * cd_speed
    _cooldown_remaining = max(_cooldown_remaining, 0.0)
    _last_tick_ms = now
```

---

## QA Test Cases

- 正常冷却: 充能=1 → 15s 后技能就绪（±0.3s）
- 充能加速: 充能=3 → 3s 计时 → 冷却减少 6s（cd_speed=2.0）
- CD 缩减: 极限闪避 → CD -8s
- 上限: 连续 3 次极限闪避 → CD 累计缩减停在 9s

## Test Evidence: `tests/unit/skill/cooldown_test.gd`
## Dependencies

- Depends on: DodgeSystem (`get_charge_count()`, dodge events)
- Unlocks: Story 002 (skill_2), Story 003 (charge orb)
