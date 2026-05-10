# 菜单系统

> **Status**: Approved
> **Author**: user + agents
> **Last Updated**: 2026-05-07

## Overview

菜单系统管理主菜单和死亡结算两个非战斗界面的 UI。主菜单——冷蓝工业氛围、标题、开始按钮。死亡结算——暖暮琥珀、本局统计、返回按钮。完整视觉风格见美术圣经 §2（氛围 §6：暖暮余烬）。

## Detailed Design

**主菜单**：场景 `main_menu.tscn`。标题（12px 像素粗体）+ "开始游戏"按钮 + 背景（工业冷蓝，扫描线/网格）

**死亡结算**：场景 `death_screen.tscn`。统计（波次、击杀、构筑选择）逐个浮现动画 + "返回主菜单"按钮

**暂停菜单**：战斗中 Esc → 最小暂停（冻结画面 + "继续"/"退出"两个选项）。无复杂菜单层级。

## Dependencies

- 场景管理 F2（场景切换）、跨局进度 F7（统计数据）

## Acceptance Criteria

- **GIVEN** 游戏启动，**WHEN** 加载完毕，**THEN** 主菜单显示+冷蓝 BGM
- **GIVEN** 点击"开始"，**WHEN** 加载战斗场景，**THEN** 300ms 内进入战斗
- **GIVEN** 玩家死亡，**WHEN** 结算画面出现，**THEN** 波次+击杀+构筑统计逐个显示
