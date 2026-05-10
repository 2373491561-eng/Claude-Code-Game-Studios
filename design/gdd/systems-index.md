# Systems Index: 裂隙反应

> **Status**: Draft
> **Created**: 2026-05-07
> **Last Updated**: 2026-05-07
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

《裂隙反应》是一款 45 度俯视角射击 Roguelike，核心循环为"射击清理杂兵 → 闪避充能 → 技能爆发 → 每波结束3选1构筑"。系统规模聚焦于核心战斗体验——20 个系统覆盖输入到打磨的全部层级。闪避充能和构筑选择是两大设计支柱的系统载体，VFX 反馈密度是贯穿所有系统的横向需求。

---

## Systems Enumeration

| # | System | Category | Priority | Status | Design Doc | Depends On |
|---|--------|----------|----------|--------|------------|------------|
| 1 | 输入系统 | Foundation | MVP | Approved | [input-system.md](input-system.md) | — |
| 2 | 场景管理 | Foundation | MVP | Approved | [scene-management.md](scene-management.md) | — |
| 3 | 音频系统 | Foundation | MVP | Approved | [audio-system.md](audio-system.md) | — |
| 4 | 摄像机系统 | Foundation | MVP | Approved | [camera-system.md](camera-system.md) | — |
| 5 | 玩家移动 | Core | MVP | Approved | [player-movement.md](player-movement.md) | 1 |
| 6 | 射击系统 | Core | MVP | Approved | [shooting-system.md](shooting-system.md) | 1, 5 |
| 7 | 闪避系统 | Core | MVP | Approved | [dodge-system.md](dodge-system.md) | 1, 5, 9 |
| 8 | 技能系统 | Core | MVP | Approved | [skill-system.md](skill-system.md) | 1, 7, 6 |
| 9 | 伤害与血量 | Core | MVP | Approved | [damage-health.md](damage-health.md) | 7, 10 |
| 10 | 敌人系统 | Core | MVP | Approved | [enemy-system.md](enemy-system.md) | 2, 5, 9 |
| 11 | 构筑系统 | Feature | MVP | Approved | [build-system.md](build-system.md) | 12 |
| 12 | 波次管理 | Feature | MVP | Approved | [wave-management.md](wave-management.md) | 10, 11 |
| 13 | VFX/粒子特效 | Presentation | MVP | Approved | [vfx-particles.md](vfx-particles.md) | 6, 7, 8, 10 |
| 14 | Diegetic UI | Presentation | MVP | Approved | [diegetic-ui.md](diegetic-ui.md) | 7, 8, 9 |
| 15 | HUD | Presentation | MVP | Approved | [hud.md](hud.md) | 12, 10, 8 |
| 16 | 升级卡片 UI | Presentation | MVP | Approved | [upgrade-card-ui.md](upgrade-card-ui.md) | 11 |
| 17 | 跨局进度 | Feature | Vertical Slice | Approved | [meta-progression.md](meta-progression.md) | 12 |
| 18 | 菜单系统 | Presentation | Vertical Slice | Approved | [menu-system.md](menu-system.md) | 2 |
| 19 | 存档系统 | Polish | Alpha | Designed | [save-system.md](save-system.md) | 17 |
| 20 | 设置系统 | Polish | Full Vision | Designed | [settings-system.md](settings-system.md) | 1, 3 |

---

## Categories

| Category | Description | Systems |
|----------|-------------|---------|
| **Foundation** | 所有系统依赖的基础设施——没有它们什么都不运作 | 输入、场景管理、音频、摄像机 |
| **Core** | 让游戏"可玩"的系统——30秒循环的物理载体 | 移动、射击、闪避、技能、血量、敌人 |
| **Feature** | 赋予游戏深度和独特性的系统——支柱的实现层 | 构筑、波次管理、跨局进度 |
| **Presentation** | 玩家看到和听到的一切——反馈密度和 UI 信息层 | VFX、Diegetic UI、HUD、升级卡片、菜单 |
| **Polish** | 完整发布所需的收尾系统 | 存档、设置 |

---

## Priority Tiers

| Tier | Definition | System Count |
|------|------------|:---:|
| **MVP** | 核心循环所需的全部系统——没有它们就无法验证"闪避充能 + 构筑"是否好玩 | 16 |
| **Vertical Slice** | 完整的单局体验 + 跨局解锁——玩家可以从菜单开始到结算 | 2 |
| **Alpha** | 跨局进度持久化——进度不会丢失 | 1 |
| **Full Vision** | 完整发布品质——玩家可自定义设置 | 1 |

---

## Dependency Map

### Foundation Layer（无依赖 — 最先构建）

1. 输入系统 — 所有玩家操作的基础
2. 场景管理 — 承载所有游戏对象的容器
3. 音频系统 — 支柱2反馈三要素之一（视觉+触觉+听觉）
4. 摄像机系统 — 45度俯视角 + 屏幕震动 = 感官核心

### Core Layer（依赖 Foundation）

1. 玩家移动 — depends on: 1
2. 射击系统 — depends on: 1, 5
3. 伤害与血量 — depends on: 7, 10（通过接口解耦）
4. 闪避系统 — depends on: 1, 5, 9（接口：`is_invincible()`, `get_charge_count()`）
5. 技能系统 — depends on: 1, 7, 6
6. 敌人系统 — depends on: 2, 5, 9

### Feature Layer（依赖 Core）

1. 波次管理 — depends on: 10, 11
2. 构筑系统 — depends on: 12
3. 跨局进度 — depends on: 12

### Presentation Layer（依赖 Core + Feature）

1. VFX/粒子特效 — depends on: 6, 7, 8, 10
2. Diegetic UI — depends on: 7, 8, 9
3. HUD — depends on: 12, 10, 8
4. 升级卡片 UI — depends on: 11
5. 菜单系统 — depends on: 2

### Polish Layer（依赖一切）

1. 存档系统 — depends on: 17
2. 设置系统 — depends on: 1, 3

---

## Recommended Design Order

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|:---:|
| 1 | 输入系统 | MVP | Foundation | S |
| 2 | 场景管理 | MVP | Foundation | S |
| 3 | 摄像机系统 | MVP | Foundation | S |
| 4 | 音频系统 | MVP | Foundation | S |
| 5 | 玩家移动 | MVP | Core | S |
| 6 | 射击系统 | MVP | Core | M |
| 7 | 伤害与血量 | MVP | Core | S |
| 8 | 闪避系统 | MVP | Core | M |
| 9 | 技能系统 | MVP | Core | M |
| 10 | 敌人系统 | MVP | Core | M |
| 11 | 波次管理 | MVP | Feature | M |
| 12 | 构筑系统 | MVP | Feature | M |
| 13 | VFX/粒子特效 | MVP | Presentation | M |
| 14 | Diegetic UI | MVP | Presentation | S |
| 15 | HUD | MVP | Presentation | S |
| 16 | 升级卡片 UI | MVP | Presentation | S |
| 17 | 跨局进度 | Vertical Slice | Feature | S |
| 18 | 菜单系统 | Vertical Slice | Presentation | M |
| 19 | 存档系统 | Alpha | Polish | S |
| 20 | 设置系统 | Full Vision | Polish | S |

---

## Circular Dependencies

**C7 闪避 ↔ C9 血量**：
- 闪避恢复血量（闪避 → 血量）
- 伤害判断需要知道无敌帧状态（血量 → 闪避）
- **解决**：闪避系统暴露公共接口 `is_invincible(): bool` / `get_charge_count(): int`，伤害系统通过接口读取状态，不依赖闪避内部实现

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| 闪避系统 | Design | 核心手感——充能次数、极限闪避窗口、无敌帧长度这三个参数的任何微调都改变游戏整体感受 | 原型中暴露为可调参数，反复 playtest |
| 敌人系统 | Technical | 50+ 敌人同屏 AI + 渲染——如果每个敌人独立 `_process()` 会撑爆帧预算 | 集中式敌人管理器 + MultiMeshInstance2D 批量渲染 |
| 构筑系统 | Design | 12 个升级选项的平衡——如果有 1-2 个选项明显最强，构筑深度就消失了 | MVP 手动测试所有组合，收集选择率数据 |
| VFX/粒子特效 | Technical | 同屏 50+ 敌人 + 技能爆发 800 粒子峰值——如果粒子系统不做对象池会卡顿 | 粒子池预分配 + GPU 粒子模式 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 20 |
| Design docs started | 20 |
| Design docs reviewed | 20 |
| Design docs approved | 18 |
| MVP systems designed | 16/16 |
| MVP systems approved | 16/16 |
| Vertical Slice systems designed | 0/2 |

---

## Next Steps

- [ ] 按设计顺序编写 GDD — 从 `输入系统` 开始（`/design-system 输入系统`）
- [ ] 运行 `/design-review` 审查每个完成的 GDD
- [ ] 运行 `/prototype 闪避系统` — 最高风险系统先验证
- [ ] MVP 全部 GDD 完成后运行 `/gate-check pre-production`
