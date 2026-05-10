# Epic: 构筑系统

> **Layer**: Feature
> **GDD**: design/gdd/build-system.md
> **Architecture Module**: BuildSystem
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created

## Overview

实现 Roguelike 构筑系统——12 个基础升级选项，每波结束后随机抽取 3 张，玩家选择 1 张。已选升级不重复出现，池子耗尽后重新洗入。升级分类：武器强化(3)、技能强化(3)、闪避强化(3)、生存强化(2)、特殊(1)。所有升级效果即时生效。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Event/signal | `EventBus.upgrade_selected` | LOW |
| ADR-0010: Skill_2 pierce | Damage pipeline modifications | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-build-001 | 12 张升级池 + 每波随机 3 选 1 | 设计层，无需 ADR |
| TR-build-002 | 升级修改射击/技能/闪避/血量属性 | ADR-0010 ✅ |
| TR-build-003 | 构筑方向视觉方言切换（火/雷/虚空） | ADR-0013 ✅ |

## Definition of Done

- 12 个升级选项定义（效果+数值+视觉方言）
- 随机抽取 3 选 1 逻辑
- 升级效果即时应用（修改对应系统属性）
- 池子耗尽后重新洗入
- 所有验收标准通过测试

## Next Step

Run `/create-stories build-system`
