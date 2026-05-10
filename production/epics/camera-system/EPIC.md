# Epic: 摄像机系统

> **Layer**: Foundation
> **GDD**: design/gdd/camera-system.md
> **Architecture Module**: CameraSystem
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created — run `/create-stories camera-system`

## Overview

实现 45 度俯视角摄像机——平滑跟随玩家（lerp），向瞄准方向偏移 10-15%，鼠标滚轮缩放（1.5m–4m 等效视野），5 级屏幕震动（受击/极限闪避/技能爆发/大型敌出现/死亡）。所有震动使用真实时间衰减（`Tween.set_ignore_time_scale(true)`）。极限闪避时摄像机跟随世界减速（`Engine.time_scale = 0.2`），震动不受时间缩放影响。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0009: Camera shake | 5-level shake via `Camera2D.offset` + Tween, real-time decay | LOW |
| ADR-0001: Real-time timing | `Tween.set_ignore_time_scale(true)` for shake | LOW |
| ADR-0005: Event/signal | EventBus connections for shake triggers (dodge_perfect, skill_1_cast, player_hit, player_death) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-cam-001 | 跟随 + 瞄准偏移 + 缩放（1.5m–4m） | ADR-0009 ✅ |
| TR-cam-002 | 5 级震动系统（受击/闪避/爆发/大型敌/死亡）真实时间衰减 | ADR-0009 ✅ |

## Definition of Done

- Camera2D 平滑跟随玩家（lerp speed 0.15）
- 瞄准偏移正确（max 80px，ease-out）
- 鼠标滚轮缩放正确（zoom 1.0–3.0，0.2s 过渡）
- 5 级震动正确（受击 100ms / 极限闪避 150ms / 技能爆发 300ms / 大型敌 200ms / 死亡 500ms）
- 震动不受 `Engine.time_scale` 影响
- 摄像机 clamp 到场景边界内
- 同时多个震动只取最强（不叠加）
- 所有验收标准通过测试

## Next Step

Run `/create-stories camera-system` to break this epic into implementable stories.
