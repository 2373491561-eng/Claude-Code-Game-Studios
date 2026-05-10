# Epic: 音频系统

> **Layer**: Foundation
> **GDD**: design/gdd/audio-system.md
> **Architecture Module**: AudioSystem + AudioManager
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created — run `/create-stories audio-system`

## Overview

实现音频总线架构（Master → BGM / SFX[Weapon/Impact/Dodge/Skill/Enemy] / UI）和音频事件系统。技能爆发时触发三级 Ducking（Attack 50ms → Hold 450ms → Release 500ms），BGM -12dB 让步。所有 Ducking、BGM 交叉淡入淡出使用真实时间（`Tween.set_ignore_time_scale(true)`）。极限闪避时世界音效音高下降 2 个八度，技能爆发音效保持正常音高。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Event/signal | EventBus signal connections for all audio events | LOW |
| ADR-0008: Audio ducking | 3-phase ducking via `AudioServer.set_bus_volume_db()` | LOW |
| ADR-0001: Real-time timing | All ducking/bgm fade via `Tween.set_ignore_time_scale(true)` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-audio-001 | 总线结构 + Ducking（Attack/Hold/Release） | ADR-0008 ✅ |
| TR-audio-002 | 时间缩放音高（world SFX pitch down, skill burst normal） | ADR-0008 ✅ |

## Definition of Done

- 8 条音频总线创建并配置
- AudioManager Autoload 跨场景 BGM 连续播放
- BGM 交叉淡入淡出（1s，可配置）
- 技能爆发 Ducking 正确（Attack 50ms → Hold 450ms → Release 500ms）
- Ducking 总线按表衰减（BGM -12dB, SFX/Weapon -9dB, SFX/Dodge -6dB 等）
- 极限闪避时世界音效音高下降 2 个八度
- 技能爆发音效保持正常音高（不受时间缩放影响）
- 暂停时所有音频暂停
- 最大同时 SFX 数 = 8，超限终止最早者
- 所有验收标准通过测试

## Next Step

Run `/create-stories audio-system` to break this epic into implementable stories.
