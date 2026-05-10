# Story 002: 技能爆发 Ducking + 时间缩放音高

> **Epic**: audio-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-audio-001`, `TR-audio-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Audio Ducking, ADR-0001: Real-Time Timing
**ADR Decision Summary**: 技能 1 爆发触发三级 Ducking：Attack 50ms → Hold 450ms → Release 500ms。使用 `AudioServer.set_bus_volume_db()` + `tween_method()`。Kill 前一个 Tween 防止重叠。所有 Ducking 使用真实时间（`tween.set_ignore_time_scale(true)`）。极限闪避时世界音效音高下降 2 个八度（`pitch_scale = 0.25`），技能爆发音效保持正常音高。

**Engine**: Godot 4.6.2 | **Risk**: LOW（已修复 API 误用）
**Engine Notes**: 使用 `AudioServer.get_bus_index()` 解析总线名 → `AudioServer.set_bus_volume_db()` 调整音量。不要使用 `get_bus_effect()`。

**Control Manifest Rules (Presentation)**:
- Required: Attack 50ms → Hold 450ms → Release 500ms；Kill 前一个 ducking tween；使用 `get_bus_index()` + `set_bus_volume_db()`
- Forbidden: 不要使用 `AudioServer.get_bus_effect(name_string, 0)`；不要 Duck SFX/Skill 总线

---

## Acceptance Criteria

- [ ] 技能爆发触发 Ducking：BGM -12dB, SFX/Weapon -9dB, SFX/Dodge -6dB, SFX/Impact -6dB, SFX/Enemy -9dB, UI -6dB
- [ ] SFX/Skill 总线 0dB（不参与 Ducking）
- [ ] Ducking 时间线：Attack 50ms → Hold 450ms → Release 500ms（ease-out）
- [ ] Ducking 使用真实时间（`tween.set_ignore_time_scale(true)`）——time_scale=0.2 期间仍以真实时间完成
- [ ] 技能爆发在 Ducking 期间再次释放 → Kill 旧 Tween，启动新 Ducking 周期
- [ ] 极限闪避 `time_scale=0.2` 时：世界音效（Weapon/Impact/Enemy 总线）`pitch_scale = 0.25`（音高 -2 八度）
- [ ] 技能爆发音效（SFX/Skill）`pitch_scale = 1.0`（正常音高，不受时间缩放影响）

---

## Implementation Notes

```gdscript
var _duck_tweens: Array[Tween] = []

func _apply_ducking() -> void:
    for t in _duck_tweens:
        if t.is_valid(): t.kill()
    _duck_tweens.clear()
    var configs = [
        {bus="BGM", target=-12.0}, {bus="SFX/Weapon", target=-9.0},
        {bus="SFX/Dodge", target=-6.0}, {bus="SFX/Impact", target=-6.0},
        {bus="SFX/Enemy", target=-9.0}, {bus="UI", target=-6.0},
    ]
    for cfg in configs:
        var idx = AudioServer.get_bus_index(cfg.bus)
        var tween = create_tween()
        tween.set_ignore_time_scale(true)
        tween.tween_method(AudioServer.set_bus_volume_db.bind(idx),
            AudioServer.get_bus_volume_db(idx), cfg.target, 0.05)
        tween.tween_interval(0.45)
        tween.tween_method(AudioServer.set_bus_volume_db.bind(idx),
            cfg.target, 0.0, 0.5)
        _duck_tweens.append(tween)
```

---

## QA Test Cases

- Ducking depth: 技能爆发 → BGM 音量在 50ms 内降至 -12dB ±2dB
- Ducking timeline: Attack 50ms + Hold 450ms + Release 500ms = 总 1s ——测量 BGM 音量恢复到 0dB 的时间
- Tween kill: 爆发 1 → 200ms 后爆发 2 → 爆发 1 的 Tween 被 kill，爆发 2 的 Ducking 正常完成
- Pitch: time_scale=0.2 → SFX/Weapon 音高降至 0.25x

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio/ducking_test.gd`

## Dependencies

- Depends on: Story 001 (audio bus + EventBus connections), ADR-0005 (EventBus)
- Unlocks: None
