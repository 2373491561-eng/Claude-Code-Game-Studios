# Story 002: 极限闪避检测 + 时间缩放

> **Epic**: dodge-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/dodge-system.md`
**Requirement**: `TR-dodge-002`, `TR-dodge-003`
**ADR Governing Implementation**: ADR-0007: Perfect Dodge Detection, ADR-0001: Real-Time Timing
**ADR Decision Summary**: O(N) `distance_squared_to()` 检测所有攻击位置（敌人位置 + 在途子弹）。最近攻击 ≤40px → 极限闪避。充能≥1 时：time_scale=0.2（200ms）+ ease-out-expo 恢复 + 硬钳位 t≥1.0。充能=0 时：仅无敌帧。不消耗充能。多目标在范围内只触发 1 次。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: O(N) `distance_squared_to()`；40px 阈值；`EnemyManager.get_all_attack_positions()` 接口
- Forbidden: 不要用 Area2D 触发器做完美闪避检测；不要忘记 time_scale 恢复曲线的硬钳位

---

## Acceptance Criteria

- [ ] 极限闪避判定：`EnemyManager.get_all_attack_positions()` 中任一位置距玩家 ≤40px
- [ ] 5 种攻击类型全部检测：小型接触、中型子弹、中型接触、大型近战、大型冲锋
- [ ] 充能≥1 时极限闪避 → time_scale=0.2，200ms 真实时间后 ease-out-expo 恢复
- [ ] 恢复曲线：`f(t) = clamp(1.0 - 0.8 × e^(-6t), 0.2, 1.0)`，t≥1.0 硬钳位至 1.0
- [ ] 充能≥1 时：回血 1 + 护盾 1（3s）+ 技能 CD -8s + skill_2 窗口 500ms
- [ ] 充能=0 时：仅无敌帧 300ms，无时间缩放/回血/护盾/CD缩减
- [ ] 不消耗充能
- [ ] 多目标在 40px 内 → 只触发 1 次，取最近攻击
- [ ] 极限闪避进行中再次触发 → 忽略（不叠加 time_scale）
- [ ] 使用 `distance_squared_to()` 避免不必要的 `sqrt()`（仅找到候选时才 `sqrt`）

---

## Implementation Notes

```gdscript
const PERFECT_DISTANCE = 40.0
func _check_perfect_dodge(player_pos: Vector2) -> bool:
    var attacks = enemy_manager.get_all_attack_positions()
    var nearest_sq = PERFECT_DISTANCE * PERFECT_DISTANCE
    for pos in attacks:
        var dist_sq = player_pos.distance_squared_to(pos)
        if dist_sq < nearest_sq:
            nearest_sq = dist_sq
    return nearest_sq < PERFECT_DISTANCE * PERFECT_DISTANCE
```

## QA Test Cases

- AC3a: 小型敌人距玩家 39px 按闪避 → 极限闪避触发（time_scale=0.2）
- AC3c: 多枚攻击同时在 40px 内 → 只触发 1 次，time_scale 保持 0.2
- AC3d: 充能=0，攻击 ≤40px → 极限闪避仅无敌帧，time_scale=1.0
- 恢复钳位: time_scale 恢复后 `abs(time_scale - 1.0) < 0.001`

## Test Evidence: `tests/unit/dodge/perfect_dodge_test.gd`
## Dependencies

- Depends on: Story 001 (charge + displacement), EnemyManager (`get_all_attack_positions`)
- Unlocks: Story 003 (post-dodge state), skill-system (skill_2 window, CD reduction)
