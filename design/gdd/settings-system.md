# 设置系统

> **Status**: Designed (pending review)
> **Author**: user + agents
> **Last Updated**: 2026-05-07

## Overview

设置系统管理玩家可调整的游戏参数——音量（Master/BGM/SFX 三通道）、按键绑定（预留）、画面设置（预留）。MVP 阶段仅实现音量控制。设置通过存档系统持久化。

## Detailed Design

**音量控制**：主菜单和暂停菜单中可访问。三通道独立滑块：Master（0-100%）、BGM（0-100%）、SFX（0-100%）。实时预览——拖动滑块时播放测试音。

**按键配置**：MVP 不做——使用固定映射。代码中所有按键通过 Input Map 引用（已由输入系统 GDD 约束），为未来自定义绑定留好扩展点。

**画面设置**：MVP 不做——固定 960×540 渲染分辨率，整数倍拉伸。

## Dependencies

- 音频系统 F3（音量控制）、输入系统 F1（Input Map）、存档 PL1（持久化）

## Acceptance Criteria

- **GIVEN** 玩家拖动 SFX 滑块至 50%，**WHEN** 释放滑块，**THEN** SFX 音量降至 50%
- **GIVEN** 设置变更后重启游戏，**WHEN** 加载存档，**THEN** 音量设置保留
