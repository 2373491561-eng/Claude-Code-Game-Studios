# Epic: 输入系统

> **Layer**: Foundation
> **GDD**: design/gdd/input-system.md
> **Architecture Module**: InputSystem
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: 4 stories created (2026-05-10)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Input Map 搭建与核心轮询 | Logic | Ready | ADR-0002 |
| 002 | 双通道闪避去抖与缓冲 | Logic | Ready | ADR-0001, ADR-0002 |
| 003 | 输入状态机 | Integration | Ready | ADR-0002 |
| 004 | 暂停与失焦处理 | Logic | Ready | ADR-0002 |

## Overview

实现《裂隙反应》的输入处理层——WASD 八方向移动、鼠标瞄准、左键射击、Shift/右键双通道闪避、空格技能、Esc 暂停。所有游戏输入统一在 `_physics_process()` 中通过 `Input.is_action_just_pressed()` 处理，`_input()` 仅做轻量去抖和缓冲标记。同帧优先级：闪避 → 技能1 → 射击（取消优先规则）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Real-time timing | `Time.get_ticks_msec()` for debounce/buffer timestamps | LOW |
| ADR-0002: Input processing | Unified `_physics_process()` input, `_input()` flag-only | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-input-001 | 双通道闪避去抖 50ms + 缓冲 100ms | ADR-0002 ✅ |
| TR-input-002 | 输入统一 `_physics_process`，同帧优先级可控 | ADR-0002 ✅ |

## Definition of Done

- 7 个 Input Map 动作注册（move/aim/shoot/dodge/skill_1/skill_2/pause）
- 双通道闪避去抖正确（Shift + 右键 50ms 内只触发 1 次）
- 输入缓冲正确（闪避结束前 100ms 按下 → 自动触发下一次）
- 同帧取消优先规则正确（闪避取消技能1 → 退还 75% CD）
- 闪避期间移动/射击锁定，技能1不锁定
- 闪避结束自动恢复射击
- 暂停（Esc）和失焦（Alt+Tab）正确处理
- 所有验收标准通过测试

## Next Step

Run `/create-stories input-system` to break this epic into implementable stories.
