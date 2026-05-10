# Story 003: AudioManager Autoload + BGM 跨场景连续性

> **Epic**: scene-management
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/scene-management.md`
**Requirement**: `TR-scene-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Scene Lifecycle & Autoload Design
**ADR Decision Summary**: AudioManager 作为 Autoload 管理跨场景 BGM 连续性。`crossfade_bgm(target_state, duration)` 实现无缝过渡。BGM 状态：NONE / MENU / COMBAT / DEATH。

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `AudioStreamPlayer` + `Tween` 实现交叉淡入淡出——均在训练数据内。

**Control Manifest Rules (Foundation)**:
- Required: Autoload 在 `project.godot` 中注册；BGM 过渡使用 `Tween`；`Tween.set_ignore_time_scale(true)`
- Forbidden: 不要在场景切换时硬切 BGM

---

## Acceptance Criteria

- [ ] AudioManager 在 `project.godot` 中注册为 Autoload（`class_name AudioManager extends Node`）
- [ ] `BGMState` 枚举：NONE, MENU, COMBAT, DEATH
- [ ] `crossfade_bgm(target: BGMState, duration: float = 0.5)` — 淡出当前 BGM + 淡入目标 BGM
- [ ] 同一状态重复调用 `crossfade_bgm()` 不重复触发过渡
- [ ] BGM 过渡使用 `Tween` + `set_ignore_time_scale(true)`
- [ ] BGM 在场景切换之间不中断（AudioManager 是 Autoload，不受场景切换影响）

---

## Implementation Notes

```gdscript
class_name AudioManager extends Node

enum BGMState { NONE, MENU, COMBAT, DEATH }
var _current_bgm: BGMState = BGMState.NONE
var _bgm_player: AudioStreamPlayer

func crossfade_bgm(target: BGMState, duration: float = 0.5) -> void:
    if _current_bgm == target: return
    var tween = create_tween()
    tween.set_ignore_time_scale(true)
    tween.tween_property(_bgm_player, "volume_db", -80.0, duration * 0.5)
    tween.tween_callback(_switch_bgm.bind(target))
    tween.tween_property(_bgm_player, "volume_db", 0.0, duration * 0.5)
    _current_bgm = target
```

---

## QA Test Cases

- **连续**: 菜单 BGM 播放 → 进入战斗（crossfade to COMBAT 1s）→ BGM 不中断（淡入淡出过渡）
- **幂等**: `crossfade_bgm(COMBAT)` 时状态已是 COMBAT → 不触发过渡
- **时间缩放**: `Engine.time_scale = 0.2` 时 BGM 过渡仍以真实时间完成

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scene/audio_manager_test.gd` OR manual playtest doc

## Dependencies

- Depends on: Story 001 (GameManager), Story 002 (SceneManager — scene switch triggers BGM change)
- Unlocks: None
