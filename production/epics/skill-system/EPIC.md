# Epic: 技能系统

> **Layer**: Core
> **GDD**: design/gdd/skill-system.md
> **Architecture Module**: SkillSystem
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created — run `/create-stories skill-system`

## Overview

实现双技能系统——技能 1（电光蓝冲击波，空格键，15s CD）和技能 2（自动附加，极限闪避后 500ms 窗口）。技能 1：圆形 AoE 200px 半径，基础伤害 1，冷却速度与闪避充能挂钩（充能 3 → 2 倍速，等效 7.5s）。闪避缩短 CD（普通 -3s，极限 -8s）。启动阶段 0-200ms 可取消，退还 75% CD。CD 缩减单周期上限 60%（9s）。技能 2：极限闪避（充能≥1）后 500ms 窗口内下一次攻击自动附加伤害×2 + 穿透 1。充能球 Diegetic UI 四态视觉（灰蓝→冷青→电光蓝→橙红脉动）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Real-time timing | Cooldown uses `Time.get_ticks_msec()`, not `delta` | LOW |
| ADR-0010: Skill_2 pierce | Auto-attach via manual `check_bullet_hit()` double pass | LOW |
| ADR-0007: Perfect dodge | Skill_2 window opened by perfect dodge (charge≥1) | LOW |
| ADR-0005: Event/signal | `EventBus.skill_1_cast` for VFX/audio/camera | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-skill-001 | 技能 1 CD 15s + AoE 200px + 充能加速冷却 | ADR-0001 ✅ |
| TR-skill-002 | 技能 2 自动附加（极限闪避后 500ms 窗口） | ADR-0010 ✅ |
| TR-skill-003 | 充能球 UI 四态视觉 | ADR-0005 ✅ |

## Definition of Done

- 技能 1：空格触发，200px 圆形 AoE，基础伤害 1
- 冷却 15s 真实时间，充能加速（×1.0/×1.5/×2.0）
- 闪避缩减 CD（普通 -3s，极限 -8s，充能门控）
- CD 缩减上限 9s（60%），超出忽略+金色闪烁
- 取消退还 75% CD（仅前 200ms 启动阶段）
- 技能 2：极限闪避（充能≥1）后 500ms 窗口自动附加
- skill_2 窗口内再次极限闪避 → 窗口刷新
- 充能球四态视觉（灰蓝→冷青→电光蓝→橙红脉动）
- 冷却中按空格 → 红色闪烁反馈
- 同帧闪避取消优先（AC7）
- 所有 14 个 AC 通过测试

## Next Step

Run `/create-stories skill-system` to break this epic into implementable stories.
