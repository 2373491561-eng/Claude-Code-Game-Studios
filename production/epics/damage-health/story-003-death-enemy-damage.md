# Story 003: 死亡冻结 + 敌人受击伤害管道

> **Epic**: damage-health
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/damage-health.md`
**Requirement**: `TR-dmg-001`
**ADR Governing Implementation**: ADR-0001: Real-Time Timing, ADR-0005: Event/Signal Architecture
**ADR Decision Summary**: HP=0 → 死亡冻结 500ms 真实时间（敌人 AI + 子弹 + 输入冻结，VFX/摄像机继续）→ `SceneManager.switch_to("death_screen")`。敌人受击伤害管道：`base(1) + build_bonus → ×2(skill_2) → apply to enemy_hp`。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: 死亡冻结使用 `Time.get_ticks_msec()`；死亡优先于回血
- Forbidden: 不要保存 Run 状态到磁盘（死亡直接切场景）

---

## Acceptance Criteria

- [ ] HP ≤ 0 → `is_dead = true`
- [ ] 死亡冻结 500ms 真实时间：所有敌人 AI + 子弹 + 玩家输入停止
- [ ] 冻结期间 VFX 和摄像机继续运行（视觉效果不冻结）
- [ ] 500ms 后调用 `SceneManager.switch_to("death_screen")` 携带 Run 统计
- [ ] `EventBus.player_death.emit(stats)` 发射死亡信号
- [ ] 死亡瞬间极限闪避 → 不回血（`hp > 0` 守卫）
- [ ] 敌人受击：`final_dmg = (base_player_damage + build_bonus) * (2 if skill_2 else 1)`
- [ ] 小型 HP=1 → 1 发击杀；中型 HP=3 → 3 发；大型 HP=8 → 8 发
- [ ] 构筑加成 +1 → 中型 2 发击杀（伤害 2/shot）

---

## Implementation Notes

```gdscript
func _on_death() -> void:
    is_dead = true
    death_freeze_start_ms = Time.get_ticks_msec()
    EventBus.player_death.emit(GameManager.current_run)
    # freeze enemies + bullets via EventBus or direct call
    # after 500ms (checked in _process): SceneManager.switch_to("death_screen")

func compute_player_damage() -> int:
    var dmg = BASE_DAMAGE + build_bonus
    if skill_system.is_skill2_window_open(): dmg *= 2
    return dmg
```

---

## QA Test Cases

- AC2: HP=1 受击 → HP=0 → 500ms 冻结 → 切换死亡场景
- AC11: HP=0 + 同帧极限闪避 → HP 保持 0
- AC16-20: 各种敌人 HP/伤害组合验证
- 伤害管道: 基础 1 + 构筑 +1 + skill_2 ×2 = 4 damage

## Test Evidence: `tests/integration/damage/death_pipeline_test.gd`
## Dependencies

- Depends on: Story 001, Story 002, GameManager, SceneManager, EnemySystem
- Unlocks: SceneManager (death screen transition)
