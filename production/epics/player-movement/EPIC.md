# Epic: 玩家移动

> **Layer**: Core
> **GDD**: design/gdd/player-movement.md
> **Architecture Module**: PlayerMovement
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created — run `/create-stories player-movement`

## Overview

实现 WASD 八方向移动——300px/s 恒定速度，即时启停无惯性。移动与射击完全独立（射移分离），对角线归一化保证速度一致。闪避期间移动锁定，闪避结束立即恢复。使用 `CharacterBody2D.move_and_slide()` 处理碰撞。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Input processing | Reads `move` axis from InputSystem in `_physics_process()` | LOW |
| ADR-0001: Real-time timing | Movement uses `delta` (should be affected by time scale) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-move-001 | WASD 300px/s 八方向移动，对角线归一化 | ADR-0002 ✅ |

## Definition of Done

- WASD 移动正确（300px/s，8 方向）
- 对角线归一化（速度 = 300px/s，非 424px/s）
- 反向瞬切无延迟
- 闪避期间移动锁定，结束后立即恢复
- 移动与射击完全独立（边移边射）
- `CharacterBody2D.move_and_slide()` 碰撞处理
- 所有验收标准通过测试

## Next Step

Run `/create-stories player-movement` to break this epic into implementable stories.
