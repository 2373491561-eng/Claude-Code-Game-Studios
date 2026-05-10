# Epic: 波次管理

> **Layer**: Feature
> **GDD**: design/gdd/wave-management.md
> **Architecture Module**: WaveManager
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created

## Overview

实现无限波次递增系统——控制敌人生成节奏、数量和组合。每波清完后触发升级选择（暗角加深→卡片出现→选择→下一波）。不切换场景——波次过渡在战斗场景内通过 Vignette 动画完成。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Enemy manager | `spawn_wave(config)` 接口 | LOW |
| ADR-0005: Event/signal | `EventBus.wave_start` / `wave_clear` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-wv-001 | 无限波次 + 数量递增（小型+3/波，中型+2/2波，大型+1/3波） | ADR-0004 ✅ |

## Definition of Done

- 波次递增表实现（Wave 1-11+）
- 每波清空检测正确
- 波次过渡：暗角加深→升级卡片→下一波，不切换场景
- 波次计数 HUD 更新
- 所有验收标准通过测试

## Next Step

Run `/create-stories wave-management`
