# Story 001: 音频总线架构 + 事件连接

> **Epic**: audio-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: `TR-audio-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event/Signal Architecture, ADR-0008: Audio Ducking
**ADR Decision Summary**: 8 条音频总线（Master → BGM / SFX[Weapon/Impact/Dodge/Skill/Enemy] / UI）。AudioSystem 连接 EventBus 信号来触发音效。SFX/Skill 总线不参与 Ducking。

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `AudioServer` API 均在训练数据内。`AudioBus` 布局通过 `AudioServer.add_bus()` 或在 Project Settings 中预配置。

**Control Manifest Rules (Presentation)**:
- Required: 8 条音频总线结构；通过 EventBus 信号连接音效触发
- Forbidden: 不要在 Core 代码中直接调用 AudioSystem 方法

---

## Acceptance Criteria

- [ ] 8 条音频总线创建：Master → BGM / SFX/Weapon / SFX/Impact / SFX/Dodge / SFX/Skill / SFX/Enemy / UI
- [ ] AudioSystem 连接 `EventBus` 信号：`bullet_hit` → 射击音效，`dodge_perfect` → 极限闪避音效，`dodge_normal` → 普通闪避音效，`skill_1_cast` → 技能爆发音效，`enemy_killed` → 敌人死亡音效，`player_hit` → 受击音效，`player_death` → 死亡音效
- [ ] `play_sfx(event: AudioEvent, position: Vector2 = Vector2.ZERO)` 方法实现
- [ ] 最大同时 SFX 数 = 8，超限终止最早者
- [ ] 连续快速射击使用循环音轨（射击开始 → 循环开启，松开 → 停止）

---

## QA Test Cases

- 总线存在：8 条总线名称可被 `AudioServer.get_bus_index(name)` 正确解析
- 事件触发：调用 `EventBus.bullet_hit.emit(Vector2(100,200), false)` → 命中音效在 50ms 内播放
- 限制：同时播放 9 个 SFX → 最早触发者被终止

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/audio/bus_setup_test.gd`

## Dependencies

- Depends on: EventBus Autoload (ADR-0005), AudioManager Autoload (scene-management epic)
- Unlocks: Story 002 (ducking)
