# Story 001: 玩家血量 + 受击无敌帧

> **Epic**: damage-health
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/damage-health.md`
**Requirement**: `TR-dmg-001`, `TR-dmg-002`
**ADR Governing Implementation**: ADR-0001: Real-Time Timing
**ADR Decision Summary**: 玩家 HP 制（最大 3）。受击伤害取决于敌人类型（小型/中型=1，大型=2）。受击后 500ms 真实时间无敌帧。无敌帧内所有伤害忽略。读取 DodgeSystem `is_invincible()` — 闪避中也不受伤害。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: 无敌帧使用 `Time.get_ticks_msec()`；通过接口读取闪避状态（不直接访问内部）

---

## Acceptance Criteria

- [ ] HP 最大值 = 3，当前 HP 0-3
- [ ] `take_damage(incoming: int, source: Node2D)` — 小型/中型 enemy.damage=1，大型=2
- [ ] 无敌帧 500ms 真实时间——不受 `Engine.time_scale` 影响
- [ ] 无敌帧内受击 → 伤害=0，HP 不变
- [ ] 无敌帧内 DodgeSystem.is_invincible()=true → 不受伤害（闪避无敌帧优先检查）
- [ ] 护盾存在时 → 优先消耗护盾（见 Story 002）
- [ ] `is_alive(): bool` — HP > 0
- [ ] `get_hp(): int`, `get_shield(): int`, `is_invincible(): bool` 公共接口
- [ ] 受击时若 HP 实际减少 → `EventBus.player_hit.emit(damage, source_pos)`

---

## Implementation Notes

```gdscript
func take_damage(incoming: int, source: Node2D) -> void:
    if not is_alive(): return
    if dodge_system.is_invincible(): return
    if _is_in_iframes(): return
    # shield absorption handled in Story 002
    hp -= incoming
    if hp <= 0:
        hp = 0
        _on_death()
        return
    _iframe_end_ms = Time.get_ticks_msec() + IFRAME_MS
    EventBus.player_hit.emit(incoming, source.global_position)
```

---

## QA Test Cases

- AC1: HP=3，小型(伤害=1)命中 → HP=2，500ms 无敌帧
- AC2: HP=1，任意命中 → HP=0，死亡冻结
- AC3: HP=3，大型(伤害=2)命中 → HP=1
- AC5: 无敌帧内受击 → HP 不变
- AC6: time_scale=0.2 时无敌帧 500ms 真实时间后解除

## Test Evidence: `tests/unit/damage/hp_iframes_test.gd`
## Dependencies

- Depends on: DodgeSystem (`is_invincible`), EnemySystem (damage values)
- Unlocks: Story 002 (shield + heal), Story 003 (death)
