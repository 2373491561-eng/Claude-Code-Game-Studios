# Epic: 菜单系统

> **Layer**: Presentation
> **GDD**: design/gdd/menu-system.md
> **Architecture Module**: MenuSystem
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created

## Overview

实现主菜单和死亡结算两个非战斗 UI 界面。主菜单：标题+开始按钮+冷蓝工业背景。死亡结算：波次/击杀/构筑统计逐个浮现+返回按钮。暂停菜单：最小化（继续+退出）。完整视觉遵循美术圣经 §2。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006: Scene lifecycle | 场景切换驱动菜单显示 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-menu-001 | 主菜单 + 死亡结算 + 暂停菜单 | ADR-0006 ✅ |

## Definition of Done

- 主菜单：标题+开始按钮+冷蓝 BGM
- 死亡结算：统计浮现动画+返回按钮
- 暂停菜单：继续+退出两个选项
- 所有验收标准通过

## Next Step

Run `/create-stories menu-system`
