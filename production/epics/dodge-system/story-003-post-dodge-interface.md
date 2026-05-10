# Story 003: 闪避后状态 + 接口暴露

> **Epic**: dodge-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/dodge-system.md`
**Requirement**: `TR-dodge-001`, `TR-dodge-003`
**ADR Governing Implementation**: ADR-0007: Perfect Dodge Detection, ADR-0005: Event/Signal Architecture
**ADR Decision Summary**: DodgeSystem 暴露 `is_invincible(): bool`, `get_charge_count(): int`, `is_dodging(): bool`, `get_dodge_direction(): Vector2` 公共接口。通过 EventBus 发射 `dodge_perfect(pos, charge_count)` 和 `dodge_normal(pos, direction)` 信号。闪避结束穿透敌人 → 自动推出（螺旋搜索 200px）。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: 接口只读解耦（`is_invincible()`, `get_charge_count()`）
- Forbidden: 不要让 DamageHealthSystem 直接访问 DodgeSystem 内部状态

---

## Acceptance Criteria

- [ ] `is_invincible(): bool` — 闪避 300ms 期间返回 true，结束后返回 false
- [ ] `get_charge_count(): int` — 返回 `floor(charge)`，0-3
- [ ] `is_dodging(): bool` — 闪避位移期间返回 true
- [ ] 普通闪避 → `EventBus.dodge_normal.emit(position, direction)`
- [ ] 极限闪避 → `EventBus.dodge_perfect.emit(position, charge_count)`
- [ ] 闪避结束穿透敌人 → 螺旋推出至最近空位（50px 步长，8 方向，最大 200px）
- [ ] 200px 内无空位 → 受 1 点伤害 + 强制推到最近非重叠位置
- [ ] 闪避触发帧优先于伤害帧（先设无敌帧，再处理伤害）
- [ ] 极限闪避回血在闪避触发帧立即生效

---

## Implementation Notes

```gdscript
func _resolve_post_dodge_overlap() -> void:
    var search_radius = 200.0
    var step = 50.0
    for r in range(step, search_radius + 1, step):
        for angle_idx in range(8):
            var angle = TAU * angle_idx / 8.0
            var test_pos = global_position + Vector2.RIGHT.rotated(angle) * r
            if not _is_overlapping_enemy(test_pos):
                global_position = test_pos
                return
    # Fallback: take 1 damage + force push
    damage_system.take_damage(1)
    global_position += (global_position - _nearest_enemy_pos()).normalized() * search_radius
```

## QA Test Cases

- 接口: DamageHealthSystem 读取 `is_invincible()` → 无敌帧期间受击=0 伤害
- 推出: 闪避结束后在 2 个敌人中间 → 推至最近空位
- 极端: 被 50+ 敌人围死 → 受 1 点伤害 + 强制推出

## Test Evidence: `tests/integration/dodge/post_dodge_test.gd`
## Dependencies

- Depends on: Story 001, Story 002, EventBus (ADR-0005), EnemyManager
- Unlocks: damage-health epic, skill-system epic
