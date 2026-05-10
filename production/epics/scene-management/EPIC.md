# Epic: 场景管理

> **Layer**: Foundation
> **GDD**: design/gdd/scene-management.md
> **Architecture Module**: SceneManager + GameManager + AudioManager
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created — run `/create-stories scene-management`

## Overview

实现场景切换系统——3 场景流（main_menu → game → death_screen → main_menu）和 2 个 Autoload 单例（GameManager 管理 Run 状态，AudioManager 管理跨场景 BGM 连续性）。战斗场景每次新 Run 完全重新加载（零状态残留）。场景切换使用 `SceneTree.change_scene_to_file()`，带淡入淡出过渡和去抖保护。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006: Scene lifecycle | 3-scene flow + 2 Autoloads, full reload per run | LOW |
| ADR-0005: Event/signal | EventBus for cross-system signals (game_paused/resumed) | LOW |
| ADR-0014: Save system | SaveManager Autoload (future integration point) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-scene-001 | 3 场景流：菜单→战斗→死亡→菜单 | ADR-0006 ✅ |
| TR-scene-002 | GameManager + AudioManager Autoload | ADR-0006 ✅ |

## Definition of Done

- 3 个场景文件存在并可加载（main_menu.tscn, game.tscn, death_screen.tscn）
- `change_scene_to_file()` 场景切换正常
- GameManager 跨场景保持 Run 状态
- AudioManager 跨场景 BGM 无缝过渡
- 新 Run 完全清空上一局残留（敌人/粒子/UI/状态）
- 场景切换去抖（500ms 内连点只触发 1 次）
- 场景加载失败时回到主菜单（不卡黑屏）
- 所有验收标准通过测试

## Next Step

Run `/create-stories scene-management` to break this epic into implementable stories.
