# Story 004: 大型敌人 AI（冲锋 + 近战）+ 全类型集成

> **Epic**: enemy-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/enemy-system.md`
**Requirement**: `TR-enemy-001`
**ADR Governing Implementation**: ADR-0004: Enemy Manager
**ADR Decision Summary**: 大型敌人缓慢推进（60px/s），每 5-8s 触发冲锋（500ms 前摇 → 250px/s 冲刺 1s），冷却 5-8s。距离 <80px → 近战（400ms 前摇 → 2 点伤害），冷却 2-3s。受击无硬直（白帧闪烁 2 帧）。死亡多阶段爆炸 ~600ms。全类型 53 敌人集成帧时间 ≤4.17ms。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: 大型碰撞半径 32-48px；前摇期间不移动；玩家死亡时所有 AI 冻结
- Forbidden: 不要让大型冲锋叠加

---

## Acceptance Criteria

- [ ] 大型敌人：64-96px 尺寸，HP=8，碰撞半径 32-48px
- [ ] 缓慢推进 60px/s 向玩家
- [ ] 冲锋：500ms 前摇（膨胀 + 地面裂纹粒子）→ 250px/s 冲刺 1s，冷却 5-8s
- [ ] 冲锋方向锁定（前摇结束时玩家位置）
- [ ] 近战：距离 <80px → 400ms 前摇 → 2 点伤害，冷却 2-3s
- [ ] 受击：无硬直，白帧 2 帧（不中断当前动作）
- [ ] 冲锋可被闪避躲开（100px 闪避 > 75px 冲锋位移）
- [ ] 死亡：分阶段爆炸 ~600ms
- [ ] 全类型集成：53 敌人全部活跃 + 技能爆发 + 满射速 → ≤4.17ms

---

## Implementation Notes

大型近战在前摇期间暂停移动：
```gdscript
if dist < MELEE_RANGE and melee_cooldown_ready:
    _timers[i] = 0.4  # 400ms windup
    _state[i] = EnemyState.MELEE_WINDUP
# after windup:
if dist < MELEE_RANGE:  # player still in range
    player.take_damage(2)
```

---

## QA Test Cases

- 冲锋: 前摇 500ms → 锁定方向 → 250px/s 冲刺 1s
- 近战: <80px + 冷却就绪 → 400ms 前摇 → 伤害=2
- 闪避冲锋: 玩家在冲锋时按 Shift → 不被命中
- 全类型集成: 53 敌人全活跃，帧时间 ≤4.17ms（物理步 ≤0.8ms）
- 玩家死亡: 所有 AI 冻结

## Test Evidence: `tests/unit/enemy/large_ai_test.gd` + `tests/integration/enemy/full_combat_test.gd`
## Dependencies

- Depends on: Story 001, Story 002, Story 003, PlayerMovement, DamageHealthSystem
- Unlocks: WaveManager (spawn control), VFX epic
