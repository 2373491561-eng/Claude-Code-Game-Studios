# ADR-0009: Camera Shake System

## Status
Accepted

## Date
2026-05-08

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Rendering |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `Camera2D.offset` tween smoothness at 240fps |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005 (EventBus signals for shake triggers) |
| **Enables** | CameraSystem implementation |
| **Blocks** | None |

## Context

摄像机 GDD 定义了 5 级震动（受击/极限闪避/技能爆发/大型敌出现/死亡），每级有不同的强度、持续时间和衰减曲线。所有震动使用真实时间（`Tween.set_ignore_time_scale(true)`），不在时间缩放期间被拉伸。

## Decision

**5 级震动系统通过 `Camera2D.offset` + Tween 偏移实现。震动数据定义在枚举驱动的配置字典中。EventBus 触发，CameraSystem 消费。**

```gdscript
enum ShakeType { PLAYER_HIT, PERFECT_DODGE, SKILL_BURST, LARGE_ENEMY_APPEAR, DEATH }

const SHAKE_CONFIG = {
    ShakeType.PLAYER_HIT:        {intensity = 3.0,  duration = 0.10, decay = "linear"},
    ShakeType.PERFECT_DODGE:     {intensity = 5.0,  duration = 0.15, decay = "ease_out"},
    ShakeType.SKILL_BURST:       {intensity = 12.0, duration = 0.30, decay = "ease_out"},
    ShakeType.LARGE_ENEMY_APPEAR:{intensity = 8.0,  duration = 0.20, decay = "ease_in_out"},
    ShakeType.DEATH:             {intensity = 20.0, duration = 0.50, decay = "ease_out"},
}

func _trigger_shake(type: ShakeType) -> void:
    var cfg = SHAKE_CONFIG[type]
    var tween = create_tween()
    tween.set_ignore_time_scale(true)
    var offset_x = randf_range(-cfg.intensity, cfg.intensity)
    var offset_y = randf_range(-cfg.intensity, cfg.intensity)
    tween.tween_property(camera, "offset", Vector2(offset_x, offset_y), cfg.duration * 0.1)
    # 根据 decay 类型继续抖动序列...
```

## GDD Requirements Addressed

| GDD | Requirement |
|-----|------------|
| camera-system.md | 5 级震动（低/中低/高/中/重）真实时间衰减 |

## Validation Criteria
- 每级震动的视觉强度与配置匹配
- `time_scale=0.2` 期间震动仍以真实时间 300ms 完成
