# Story 002: 技能 1 AoE 释放 + 取消退还

> **Epic**: skill-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/skill-system.md`
**Requirement**: `TR-skill-001`, `TR-skill-002`
**ADR Governing Implementation**: ADR-0010: Skill_2 Pierce, ADR-0005: Event/Signal Architecture
**ADR Decision Summary**: 技能 1 圆形 AoE（200px 半径），使用缓存的 `CircleShape2D` + `PhysicsShapeQueryParameters2D` 查询范围内所有敌人。伤害 = 1（基础）。释放动画 0.5s：前 0.2s 可取消（退还 75% CD），后 0.3s 不可取消。通过 `EventBus.skill_1_cast` 通知 VFX/Audio/Camera。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: 缓存 `CircleShape2D` 和 `PhysicsShapeQueryParameters2D`（在 `_ready()` 创建一次，复用）

---

## Acceptance Criteria

- [ ] 空格键触发技能 1（冷却就绪时）
- [ ] AoE 圆形 200px 半径，`intersect_shape()` 查询范围内所有敌人
- [ ] 基础伤害 = 1（小型 HP=1 秒杀）
- [ ] 释放期间可全速移动
- [ ] 释放动画 0.5s：0-200ms 可取消（退还 75% CD），200-500ms 不可取消
- [ ] 取消退还：`cooldown_remaining -= round(cooldown_remaining * 0.75 * 10) / 10`
- [ ] 取消后退还的 CD 不受 CD 缩减上限约束
- [ ] 释放帧与闪避触发帧重合 → 取消优先，技能不触发，退还 75% CD
- [ ] 冷却中按空格 → 充能球红色闪烁 100ms
- [ ] `EventBus.skill_1_cast.emit(global_position)` 在释放时发射

---

## Implementation Notes

```gdscript
var _aoe_shape = CircleShape2D.new()  # created once in _ready()
var _aoe_query = PhysicsShapeQueryParameters2D.new()

func _ready():
    _aoe_shape.radius = 200.0
    _aoe_query.shape = _aoe_shape
    _aoe_query.collision_mask = ENEMY_LAYER

func _execute_skill_1():
    _aoe_query.transform = Transform2D(0.0, global_position)
    var hits = get_world_2d().direct_space_state.intersect_shape(_aoe_query, 256)
    for hit in hits:
        if hit.collider.has_method("take_damage"):
            hit.collider.take_damage(_skill_1_damage)
    EventBus.skill_1_cast.emit(global_position)
```

---

## QA Test Cases

- AoE: 释放 → 200px 范围内 3 个小型敌人全部受伤害 1
- 取消: 释放后 100ms 按 Shift → 退还 75% CD，AoE 不触发
- 不可取消: 释放后 300ms 按 Shift → AoE 完整触发，不退还
- 同帧取消: 同一帧 dodge + skill_1 → 取消优先，CD 从 15s 恢复至 ~3.8s

## Test Evidence: `tests/unit/skill/aoe_cancel_test.gd`
## Dependencies

- Depends on: Story 001 (cooldown), DodgeSystem (cancel trigger), EventBus
- Unlocks: Story 003 (charge orb visual)
