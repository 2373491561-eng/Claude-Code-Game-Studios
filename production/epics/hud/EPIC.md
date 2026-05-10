# Epic: HUD

> **Layer**: Presentation
> **GDD**: design/gdd/hud.md
> **Architecture Module**: HUD
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created

## Overview

实现屏幕辅助信息层——顶部波次计数+击杀数、底部武器图标+技能冷却。50% 不透明度常态，信息变化升至 85%，释放瞬间降至 20%（视觉独占权）。连接 EventBus + 直接读取系统状态。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Event/signal | EventBus 驱动 HUD 状态更新 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-hud-001 | 波次计数 + 击杀数显示，不透明度策略 | ADR-0005 ✅ |

## Definition of Done

- WAVE X 显示在左上角
- 击杀计数 × N 右上角
- 不透明度策略正确应用
- 技能释放瞬间 HUD 降至 20%
- 所有验收标准通过

## Next Step

Run `/create-stories hud`
