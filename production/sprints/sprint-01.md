# Sprint 01 — Production Kickoff — 2026-05-15 to 2026-05-28

## Sprint Goal
将 MVP 从占位方块升级为有像素素材和音效的可展示版本，新增大型敌人和构筑深度。

## Capacity
- Total days: 10（兼职 solo dev）
- Buffer (20%): 2 days
- Available: 8 days

## Tasks

### Must Have（关键路径）

| ID | Task | Owner | 预估 | 依赖 | 验收标准 |
|----|------|-------|:--:|------|------|
| S1-1 | 像素素材导入（6 件最低清单） | 美术 | 3d | — | 替换全部 ColorRect 为 Sprite2D，4 方向可辨 |
| S1-2 | 音效系统（射击/闪避/技能/命中/死亡） | 音频 | 2d | — | 5 个音效播放正常，BGM 淡入淡出 |
| S1-3 | 大型敌人/Boss | 玩法 | 2d | S1-1 | 每 5 波出现，冲锋+近战+远程，8 血，掉 2 选 1 升级 |
| S1-4 | 升级种类扩展（6→12） | 玩法 | 1d | — | 穿透弹、吸血、护盾、减速光环等 6 个新升级加入随机池 |

### Should Have

| ID | Task | Owner | 预估 | 依赖 | 验收标准 |
|----|------|-------|:--:|------|------|
| S1-5 | 正式 HUD（替换 Debug 文字） | UI | 2d | — | 顶部波次+击杀，底部技能冷却+闪避充能，像素字体 |
| S1-6 | 存档：最高波次 + 解锁内容 | 系统 | 1d | — | 重启后保留最高波次记录和解锁的升级 |

### Nice to Have

| ID | Task | Owner | 预估 | 依赖 | 验收标准 |
|----|------|-------|:--:|------|------|
| S1-7 | 平衡调优 | 设计 | 0.5d | S1-4 | `/balance-check` 无异常 |
| S1-8 | 第一版 changelog | 社区 | 0.5d | — | 面向玩家的 patch notes v0.2 |

## Carryover
无（Pre-Production 全部完成）

## Risks
| 风险 | 概率 | 影响 | 缓解 |
|------|:--:|:--:|------|
| 像素素材产出慢（自己画或找素材） | 中 | 高 | 先用 itch.io 免费素材包，不追求原创 |
| 音效找不到合适的 | 低 | 中 | 用 sfxr/jsfxr 自己合成，8-bit 风格也符合像素美术 |
| 单人时间不足 | 中 | 中 | Should Have/Nice to Have 可延期到 Sprint 2 |

## Dependencies on External Factors
- 像素素材包（itch.io 搜索 "top-down shooter pixel pack"）

## Definition of Done
- [ ] 4 个 Must Have 全部完成
- [ ] 玩法可正常运行（S1-1 素材替换不破坏游戏逻辑）
- [ ] 音效和美术风格一致（像素 + 8-bit）
- [ ] Boss 战通过 playtest 验证
