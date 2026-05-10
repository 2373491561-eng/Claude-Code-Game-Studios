# Story 002: Skill_2 穿透双射线

> **Epic**: shooting-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/shooting-system.md`, `design/gdd/skill-system.md`
**Requirement**: `TR-shoot-002`
**ADR Governing Implementation**: ADR-0010: Skill_2 Pierce in Hitscan Pipeline
**ADR Decision Summary**: skill_2 穿透通过双次手动 `check_bullet_hit()` 实现。第一射线命中后，从命中点 +2px 偏移发射第二射线。两射线在同一 `_physics_process` 帧中完成。不使用 `intersect_ray()`。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: 双次 `check_bullet_hit()` 在同一帧；第二射线从 `hit1.position + direction * 2.0` 发射
- Forbidden: 不要使用 `PhysicsRayQueryParameters2D.intersect_ray()`

---

## Acceptance Criteria

- [ ] skill_2 窗口开放 + 射击 → 伤害 ×2
- [ ] 第一射线命中后，`_pierce_remaining > 0` 时发射第二射线
- [ ] 第二射线从 `hit1.position + direction * 2.0`（偏移 2px 避免重复命中同一目标）
- [ ] 第二射线使用剩余射程（`max_dist - consumed_dist`）
- [ ] 两个目标都受到 ×2 伤害
- [ ] 只有一个目标在射线上 → 仅命中第一目标（第二射线 miss）
- [ ] skill_2 窗口过期 → 普通伤害，无穿透
- [ ] 消费 `skill_2` 窗口（调用 `skill_system.consume_skill2()`）

---

## Implementation Notes

```gdscript
if skill_system.is_skill2_window_open():
    dmg *= 2
    enemy_manager.apply_damage(hit1.index, dmg)
    if _pierce_remaining > 0:
        _pierce_remaining -= 1
        var consumed = (hit1.position - origin).length()
        var remaining = max_dist - consumed
        var pierce_origin = hit1.position + direction * 2.0
        var hit2 = enemy_manager.check_bullet_hit(pierce_origin, direction, remaining)
        if hit2.index != -1:
            enemy_manager.apply_damage(hit2.index, dmg)
    skill_system.consume_skill2()
```

---

## QA Test Cases

- 穿透 2 目标: 两敌人在射线上（间距 >20px）→ 两个都受 ×2 伤害
- 单一目标: 仅 1 敌人在射线上 → 仅命中 1 个，第二射线 miss
- 窗口过期: 极限闪避后等 501ms → 普通伤害，无穿透

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/shooting/pierce_test.gd`

## Dependencies

- Depends on: Story 001 (hitscan), SkillSystem (`is_skill2_window_open`, `consume_skill2`), DodgeSystem (triggers skill_2 window)
- Unlocks: None
