# ADR-0008: Audio Ducking Specification

## Status
Accepted

## Date
2026-05-08 (revised 2026-05-10 — fix `get_bus_effect()` API misuse, add tween kill guard)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Audio |
| **Knowledge Risk** | LOW — `AudioBus`, `Tween` all in training data |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirmed: `AudioServer.get_bus_effect()` takes `(bus_idx: int, effect_idx: int)` — code revised to use `AudioServer.get_bus_index()` + `AudioServer.set_bus_volume_db()` via `tween_method()`. Also added tween kill guard for overlapping skill casts. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005 (EventBus for skill_1_cast signal) |
| **Enables** | AudioSystem implementation |
| **Blocks** | None |
| **Ordering Note** | Implement after EventBus and AudioSystem are in place |

## Context

技能 1 爆发是游戏中最重要的音频时刻——"全场只有你有资格说话"。需要爆发音效占据整个音频空间，暂时压低其他声音。技能 GDD v3 + 音频 GDD v1 定义了 Ducking 参数。此 ADR 将其转化为精确的技术规格。

## Decision

**技能 1 爆发触发三级 Ducking：Attack 50ms → Hold 450ms → Release 500ms。所有 Ducking 使用真实时间（`Tween.set_ignore_time_scale(true)`）。SFX/Skill 总线不参与 Ducking。**

| 总线 | Duck 深度 | 理由 |
|------|:--------:|------|
| BGM | -12dB | 音乐为高潮让位 |
| SFX/Weapon | -9dB | 枪声与爆发竞争 |
| SFX/Dodge | -6dB | 闪避可能与爆发重叠 |
| SFX/Impact | -6dB | 命中确认此时次要 |
| SFX/Enemy | -9dB | 敌人音频不分散注意力 |
| UI | -6dB | 防御性——通常不与爆发重叠 |
| SFX/Skill | **0dB** | 爆发自己——不 Duck |

```gdscript
var _duck_tweens: Array[Tween] = []

func _apply_ducking() -> void:
    # Kill any in-progress ducking tweens to prevent overlapping volume fights
    for t in _duck_tweens:
        if t.is_valid():
            t.kill()
    _duck_tweens.clear()

    var duck_configs = [
        {bus = "BGM",         target_db = -12.0},
        {bus = "SFX/Weapon",  target_db = -9.0},
        {bus = "SFX/Dodge",   target_db = -6.0},
        {bus = "SFX/Impact",  target_db = -6.0},
        {bus = "SFX/Enemy",   target_db = -9.0},
        {bus = "UI",          target_db = -6.0},
    ]
    for cfg in duck_configs:
        var bus_idx = AudioServer.get_bus_index(cfg.bus)
        var tween = create_tween()
        tween.set_ignore_time_scale(true)
        # Attack: 50ms — ramp volume down
        tween.tween_method(
            AudioServer.set_bus_volume_db.bind(bus_idx),
            AudioServer.get_bus_volume_db(bus_idx), cfg.target_db, 0.05
        )
        tween.tween_interval(0.45)             # Hold: 450ms
        # Release: 500ms ease-out — ramp volume back to 0dB
        tween.tween_method(
            AudioServer.set_bus_volume_db.bind(bus_idx),
            cfg.target_db, 0.0, 0.5
        )
        _duck_tweens.append(tween)
```

## GDD Requirements Addressed

| GDD | Requirement |
|-----|------------|
| skill-system.md | BGM Ducking 0.5s 真实时间 |
| audio-system.md | Ducking 规则（Attack/Hold/Release 分离） |

## Validation Criteria
- 技能爆发触发：BGM -12dB，其他总线按表 Duck
- Ducking 期间 `Engine.time_scale = 0.2` → Ducking 仍以真实时间完成
- SFX/Skill 总线音量不变（始终 0dB）
