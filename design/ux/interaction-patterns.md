# Interaction Pattern Library — 裂隙反应

MVP 交互模式汇总。基于已批准的 GDD 和 ADR 提取。

## Core Gameplay

| Pattern | Description | Used By |
|---------|-------------|---------|
| **Hold-to-shoot** | 按住鼠标左键按射速间隔持续射击 | shooting-system |
| **Dual-channel dodge** | Shift/右键双通道触发，50ms 去抖 | input-system, dodge-system |
| **Space-for-skill** | 空格触发技能 1，冷却中按无效+红闪反馈 | skill-system |
| **Auto-attach skill_2** | 极限闪避后 500ms 窗口内下一次攻击自动附加 | skill-system, dodge-system |
| **Diegetic status** | 血量光环+充能球+闪避光点——全部在角色身上 | diegetic-ui |
| **Cancel window** | 技能 1 前 200ms 可用闪避取消，退还 75% CD | skill-system |

## Menus & UI

| Pattern | Description | Used By |
|---------|-------------|---------|
| **Scene transition** | 淡入淡出 300ms + 去抖 500ms | scene-management |
| **Wave transition** | 暗角加深 + 卡片滑入（不切换场景） | wave-management, upgrade-card-ui |
| **Card selection** | 3 选 1，点击选中+飞入吸收，去抖 500ms | upgrade-card-ui, build-system |
| **Minimal pause** | Esc → 冻结+"继续/退出"，无深层菜单 | menu-system |
| **Death flow** | 冻结 500ms → 结算统计浮现 → 返回主菜单 | damage-health, menu-system |

## Input Buffering

| Pattern | Description | Used By |
|---------|-------------|---------|
| **Dodge buffer** | 闪避结束前 100ms 按下 → 结束后自动触发 | dodge-system, input-system |
| **Dodge debounce** | 50ms 窗口内多次按下 → 合并为 1 次 | dodge-system, input-system |
| **Shot resume** | 闪避期间射击暂停，结束后若仍按住 → 自动恢复 | shooting-system, dodge-system |
