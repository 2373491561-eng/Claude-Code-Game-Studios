# ADR-0010: Skill_2 Auto-Attach & Pierce in Hitscan Pipeline

## Status
Accepted

## Date
2026-05-08 (revised 2026-05-10 — switch from `intersect_ray()` to ADR-0004 manual `check_bullet_hit()`, resolve collision detection conflict)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm manual ray-circle pierce (two passes) completes within one physics frame at 53 enemies |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (enemy manager — `check_bullet_hit()` manual detection), ADR-0007 (perfect dodge detection opens skill_2 window) |
| **Enables** | ShootingSystem skill_2 integration |
| **Blocks** | None |
| **Ordering Note** | Must use ADR-0004's manual ray-circle intersection (`check_bullet_hit`), not `PhysicsRayQueryParameters2D` — enemies are off the physics scene tree per ADR-0004 |

## Context

技能 GDD v3 确定 skill_2 为自动附加——极限闪避（充能≥1）后 500ms 窗口内下一次攻击自动获得伤害×2 + 穿透 1 个目标。射击系统是 hitscan（即时命中，命中第一个碰撞体停止）。skill_2 需要射线在第一次命中后继续飞向第二个目标。此 ADR 定义穿透在 hitscan 管道中的实现方式。

## Decision

**skill_2 穿透通过手动射线-圆相交检测实现（复用 ADR-0004 的 `check_bullet_hit()`，不使用 `PhysicsRayQueryParameters2D`——敌人不在物理场景树上）。第一射线命中后，以命中点为新起点继续发射第二射线。两射线在同一个 `_physics_process` 帧中执行。skill_2 状态由 DodgeSystem 管理，ShootingSystem 只读取。**

```gdscript
func _fire_bullet() -> void:
    var origin = player_pos
    var direction = aim_dir
    var max_dist = weapon_range
    
    # 手动射线-圆相交检测（ADR-0004 check_bullet_hit）
    # 返回 {"index": int, "position": Vector2}，index=-1 表示未命中
    var hit1 = enemy_manager.check_bullet_hit(origin, direction, max_dist)
    if hit1.index == -1:
        _show_trail(origin, origin + direction * max_dist)
        return
    
    var dmg = base_damage + build_bonus
    if skill_system.is_skill2_window_open():
        dmg *= 2
        enemy_manager.apply_damage(hit1.index, dmg)
        
        if _pierce_remaining > 0:  # 穿透
            _pierce_remaining -= 1
            var consumed_dist = (hit1.position - origin).length()
            var remaining_dist = max_dist - consumed_dist
            # 从第一个命中点稍前方发射第二射线（偏移 2px 避免重复命中同一目标）
            var pierce_origin = hit1.position + direction * 2.0
            var hit2 = enemy_manager.check_bullet_hit(pierce_origin, direction, remaining_dist)
            if hit2.index != -1:
                enemy_manager.apply_damage(hit2.index, dmg)  # 第二目标同样×2伤害
        skill_system.consume_skill2()
    else:
        enemy_manager.apply_damage(hit1.index, dmg)
```

## GDD Requirements Addressed

| GDD | Requirement |
|-----|------------|
| skill-system.md | skill_2 伤害×2 + 穿透 1，窗口内自动附加 |
| shooting-system.md | Hitscan 命中第一个敌人（手动检测，ADR-0004），skill_2 例外穿透至第二个 |

## Validation Criteria
- skill_2 窗口内命中两个排队的敌人 → 两个都受到 2× 伤害
- skill_2 窗口内命中单一敌人 → 伤害×2，无第二目标
- 窗口过期后 → 普通伤害，无穿透
