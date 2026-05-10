# Epic: 升级卡片 UI

> **Layer**: Presentation
> **GDD**: design/gdd/upgrade-card-ui.md
> **Architecture Module**: UpgradeCardUI
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created

## Overview

实现波次结束时的构筑选择界面——3 张卡片从底部滑入（拱形排列，中间上浮 8px），每张 180×240px 像素边框。玩家点击选择后：选中卡片放大闪白→飞入吸收，其余淡出。键盘快捷键 1/2/3 可选。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Event/signal | `EventBus.upgrade_selected` 通知 BuildSystem | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-card-001 | 3 卡片展示+选择动画，500ms 去抖 | ADR-0005 ✅ |

## Definition of Done

- 3 卡片从底部滑入（错开动画 0.6s）
- 卡片包含图标+名称+描述
- 点击选择+飞入吸收动画（0.3s）
- 键盘 1/2/3 快捷键
- 500ms 去抖
- 所有验收标准通过

## Next Step

Run `/create-stories upgrade-card-ui`
