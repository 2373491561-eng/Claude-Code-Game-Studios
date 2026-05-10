# Story 002: 5 级屏幕震动系统

> **Epic**: camera-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-cam-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Camera Shake System
**ADR Decision Summary**: 5 级震动通过 `Camera2D.offset` + Tween 实现。SHAKE_CONFIG 字典按 `ShakeType` 枚举驱动。所有震动使用真实时间（`set_ignore_time_scale(true)`）。同时多个震动取强度最高者。

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `Camera2D.offset` 在 240fps 渲染下 Tween 平滑——已确认。

**Control Manifest Rules (Presentation)**:
- Required: 5 级震动通过 `Camera2D.offset` + Tween；`set_ignore_time_scale(true)`
- Forbidden: 不要叠加多个震动（取最强）

---

## Acceptance Criteria

- [ ] 5 级震动：PLAYER_HIT(3px,100ms), PERFECT_DODGE(5px,150ms), SKILL_BURST(12px,300ms), LARGE_ENEMY_APPEAR(8px,200ms), DEATH(20px,500ms)
- [ ] 所有震动使用 `Tween.set_ignore_time_scale(true)`——不受 `Engine.time_scale` 影响
- [ ] 震动通过 `EventBus` 信号触发（`player_hit`, `dodge_perfect`, `skill_1_cast`, `player_death`）
- [ ] 同时多个震动触发 → 只应用强度最高者，不叠加 offset
- [ ] 震动方向随机（MVP 用随机方向）

---

## Implementation Notes

```gdscript
enum ShakeType { PLAYER_HIT, PERFECT_DODGE, SKILL_BURST, LARGE_ENEMY_APPEAR, DEATH }
const SHAKE_CONFIG = {
    ShakeType.PLAYER_HIT: {intensity=3.0, duration=0.10, decay="linear"},
    ShakeType.PERFECT_DODGE: {intensity=5.0, duration=0.15, decay="ease_out"},
    ShakeType.SKILL_BURST: {intensity=12.0, duration=0.30, decay="ease_out"},
    ShakeType.LARGE_ENEMY_APPEAR: {intensity=8.0, duration=0.20, decay="ease_in_out"},
    ShakeType.DEATH: {intensity=20.0, duration=0.50, decay="ease_out"},
}
var _active_shake_type: int = -1

func _trigger_shake(type: ShakeType) -> void:
    if _active_shake_type != -1 and SHAKE_CONFIG[_active_shake_type].intensity >= SHAKE_CONFIG[type].intensity:
        return  # 当前震动更强，忽略新震动
    _active_shake_type = type
    var cfg = SHAKE_CONFIG[type]
    var tween = create_tween()
    tween.set_ignore_time_scale(true)
    # 随机方向震动段...
    tween.tween_callback(func(): _active_shake_type = -1)
```

---

## QA Test Cases

- 5 级视觉：每级震动的视觉强度与配置匹配（截图对比参考）
- 真实时间：time_scale=0.2 时触发 SKILL_BURST → 震动 300ms 真实时间完成（不是 1.5s）
- 不叠加：同帧触发 PLAYER_HIT + SKILL_BURST → 只有 SKILL_BURST（12px > 3px）

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/camera-shake-evidence.md` + sign-off

## Dependencies

- Depends on: Story 001 (Camera2D setup), EventBus (ADR-0005)
- Unlocks: None
