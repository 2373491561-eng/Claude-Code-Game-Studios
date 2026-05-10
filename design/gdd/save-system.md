# 存档系统

> **Status**: Designed (pending review)
> **Author**: user + agents
> **Last Updated**: 2026-05-07

## Overview

存档系统负责跨局进度的持久化——解锁状态、最高记录等。使用 Godot 的 `ResourceSaver` / `ResourceLoader` 或 JSON 文件保存到 `user://` 路径。不保存单局 Run 的中间状态（Roguelike——死亡即重置）。

## Detailed Design

**保存内容**：已解锁升级列表、最高波次记录、总点数、设置（音量等）

**保存时机**：死亡结算后自动保存。设置变更时即时保存。

**格式**：JSON（`user://save_data.json`）。可读、可手动编辑、不易损坏。

## Dependencies

- 跨局进度 F7（解锁数据）、设置 PL2（音量等）

## Acceptance Criteria

- **GIVEN** 玩家解锁新升级，**WHEN** 回到主菜单后重启游戏，**THEN** 解锁状态保留
- **GIVEN** 存档文件损坏/缺失，**WHEN** 游戏启动，**THEN** 使用默认初始状态，不崩溃
