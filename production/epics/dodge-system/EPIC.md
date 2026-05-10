# Epic: 闪避系统

> **Layer**: Core
> **GDD**: design/gdd/dodge-system.md
> **Architecture Module**: DodgeSystem
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created — run `/create-stories dodge-system`

## Overview

实现闪避系统——《裂隙反应》的核心支柱（P1 闪避即武器）。3 次充能，随时间恢复（3s/次）。普通闪避消耗 1 次充能，100px 位移 + 300ms 无敌帧。极限闪避（敌方攻击在 40px 内按闪避）不消耗充能，充能≥1 时触发 time_scale=0.2（200ms）+ 回血 1 + 护盾 1 + 技能 CD -8s + skill_2 窗口。充能=0 时极限闪避仅提供无敌帧（无进攻奖励）。双通道触发（Shift/右键），50ms 去抖 + 100ms 缓冲。闪避方向=当前移动方向；无输入时=最后移动方向；从未移动=向瞄准反方向闪避。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0007: Perfect dodge | O(N) `distance_squared_to()` over 80 attack positions, 40px threshold | LOW |
| ADR-0002: Input processing | Dodge debounce + buffer in `_input()`, execution in `_physics_process()` | LOW |
| ADR-0001: Real-time timing | Dodge displacement 300ms + time_scale recovery 200ms, both real-time | LOW |
| ADR-0005: Event/signal | `EventBus.dodge_perfect` / `dodge_normal` for VFX/audio/camera | LOW |
| ADR-0004: Enemy manager | `get_all_attack_positions()` for perfect dodge scan | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-dodge-001 | 3 次充能 + 100px 位移 + 300ms 无敌帧 | ADR-0007 ✅ |
| TR-dodge-002 | 极限闪避检测（所有攻击类型，40px） | ADR-0007 ✅ |
| TR-dodge-003 | time_scale=0.2，200ms ease-out-expo 恢复 | ADR-0001, ADR-0007 ✅ |

## Definition of Done

- 3 次充能，3s/次恢复，充能向下取整显示
- 普通闪避：100px 位移 + 300ms 无敌帧 + 消耗 1 充能
- 极限闪避（攻击≤40px）：不消耗充能 + time_scale=0.2 + 回血 1 + 护盾 + CD -8s
- 充能=0 极限闪避：仅无敌帧，无进攻奖励
- 充能=0 普通闪避：不可用（无反应）
- O(N) 检测涵盖所有攻击类型（接触/子弹/近战）
- 位移使用 `get_physics_process_delta_time()`（不受 time_scale 影响）
- time_scale 恢复曲线硬钳位（t≥1.0 → 1.0）
- 闪避方向: 移动方向 → 最后方向 → 瞄准反方向
- 障碍物截断位移但无敌帧保持完整 300ms
- 闪避结束穿透敌人 → 自动推出至最近空位
- 所有 13 个 AC 通过测试

## Next Step

Run `/create-stories dodge-system` to break this epic into implementable stories.
