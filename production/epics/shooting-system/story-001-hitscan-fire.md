# Story 001: Hitscan 射击 + 手动命中检测

> **Epic**: shooting-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/shooting-system.md`
**Requirement**: `TR-shoot-001`
**ADR Governing Implementation**: ADR-0004: Enemy Manager, ADR-0010: Skill_2 Pierce
**ADR Decision Summary**: 按住鼠标左键按 8/s 射速连续射击。使用手动射线-圆相交检测（`EnemyManager.check_bullet_hit()`），不使用 `PhysicsRayQueryParameters2D`。弹道线 1px 亮色 2 帧。闪避期间暂停，结束后自动恢复。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: `EnemyManager.check_bullet_hit(origin, direction, max_dist)` 返回 `{index, position}`
- Forbidden: 不要使用 `PhysicsRayQueryParameters2D.intersect_ray()`；不要鞭尸（忽略 DEAD 状态敌人）

---

## Acceptance Criteria

- [ ] 鼠标左键按住 → 按 8/s 射速（125ms 间隔）连续射击
- [ ] 松开左键 → 立即停止射击
- [ ] 命中检测：`EnemyManager.check_bullet_hit()` 返回最近敌人索引，index=-1 表示未命中
- [ ] 命中 → 造成伤害（调用 `EnemyManager.apply_damage(index, dmg)`）
- [ ] 未命中 → 弹道线延伸到射程终点（800px）
- [ ] 弹道线：1px 亮色线，枪口→命中点/终点，持续 2 帧
- [ ] 闪避期间射击暂停，闪避结束后若仍按住 → 自动恢复
- [ ] 射速间隔内松开再按下 → 重置计时器（防宏）
- [ ] 已死亡敌人（DEAD 状态）被 `check_bullet_hit()` 跳过
- [ ] 同帧多敌人在射线上 → 命中最近者

---

## Implementation Notes

```gdscript
const FIRE_RATE = 8.0
const FIRE_INTERVAL_MS = int(1000.0 / FIRE_RATE)  # 125ms
const WEAPON_RANGE = 800.0

func _fire_bullet() -> void:
    var hit = enemy_manager.check_bullet_hit(player_pos, aim_dir, WEAPON_RANGE)
    if hit.index == -1:
        _show_trail(player_pos, player_pos + aim_dir * WEAPON_RANGE)
        return
    var dmg = base_damage + build_bonus
    if skill_system.is_skill2_window_open():
        dmg *= 2
        # Piercing handled in Story 002
    enemy_manager.apply_damage(hit.index, dmg)
    _show_trail(player_pos, hit.position)
    EventBus.bullet_hit.emit(hit.position, skill_system.is_skill2_window_open())
```

---

## QA Test Cases

- 射速: 按住射击 1 秒 → 恰好 8 发子弹（±1 发容差，首帧立即发射）
- 命中: 敌人在射线上 500px 处 → `check_bullet_hit()` 返回 {index: 0, position: (x, y)}
- 不鞭尸: 敌人 HP=0 后同帧射击 → `check_bullet_hit()` 跳过该敌人
- 闪避恢复: 闪避前按住射击 → 闪避中无子弹 → 闪避结束自动恢复射击

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/shooting/hitscan_test.gd`

## Dependencies

- Depends on: EnemyManager (`check_bullet_hit`, `apply_damage`), InputSystem
- Unlocks: Story 002 (skill_2 pierce)
