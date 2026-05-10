# Story 002: 护盾 + 闪避回血

> **Epic**: damage-health
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/damage-health.md`
**Requirement**: `TR-dmg-001`
**ADR Governing Implementation**: ADR-0001: Real-Time Timing, ADR-0007: Perfect Dodge Detection
**ADR Decision Summary**: 极限闪避（充能≥1）回血 1（不超过上限）+ 护盾 1（3s 真实时间）。护盾优先消耗——完全吸收不触发无敌帧，穿透部分触发。护盾过期归零。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: 护盾计时使用 `Time.get_ticks_msec()`；回血守卫 `hp > 0`（死亡优先）

---

## Acceptance Criteria

- [ ] 极限闪避（充能≥1） → HP+1（不超过 max_hp）+ shield=1（3s 真实时间）
- [ ] 普通闪避 → 不回血，不获得护盾
- [ ] 极限闪避（充能=0） → 不回血，无护盾
- [ ] HP 已满时极限闪避 → HP 不变，但仍获得护盾
- [ ] 护盾存在 + 小型(伤害=1)命中 → 护盾归零，HP 不变，不触发无敌帧
- [ ] 护盾存在 + 大型(伤害=2)命中 → 护盾归零，HP-1，触发无敌帧（穿透部分扣血）
- [ ] 无敌帧中受击 → 护盾不消耗（无敌帧优先）
- [ ] 护盾 3s 真实时间后过期 → shield=0
- [ ] HP=0 时极限闪避 → 不回血（死亡优先 `hp > 0` 守卫）

---

## Implementation Notes

```gdscript
func take_damage(incoming: int, source: Node2D) -> void:
    if not is_alive(): return
    if dodge_system.is_invincible(): return
    if _is_in_iframes(): return
    # Shield absorbs first
    if shield > 0:
        var absorbed = min(shield, incoming)
        shield -= absorbed
        incoming -= absorbed
    if incoming > 0:
        hp -= incoming
        if hp <= 0:
            hp = 0; _on_death(); return
        _iframe_end_ms = Time.get_ticks_msec() + IFRAME_MS
```

---

## QA Test Cases

- AC7: HP=2, 极限闪避(充能≥1) → HP=3 + shield=1
- AC8: 普通闪避 → HP 不变
- AC12: shield=1 + 小型命中 → shield=0, HP 不变, 不触发无敌帧
- AC13: shield=1 + 大型(伤害=2) → shield=0, HP-1, 触发无敌帧
- AC15: shield=1, 3s 后 → shield=0

## Test Evidence: `tests/unit/damage/shield_heal_test.gd`
## Dependencies

- Depends on: Story 001 (HP + iframes), DodgeSystem (perfect dodge signal + charge_count)
- Unlocks: Story 003 (death)
