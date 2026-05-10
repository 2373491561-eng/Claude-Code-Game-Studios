# Game Concept: 裂隙反应

*Created: 2026-05-07*
*Status: Draft*

---

## Elevator Pitch

> 这是一款 45 度俯视角射击 Roguelike 游戏，在如潮水般涌来的外星生物中，用精准闪避充能技能、构筑每局独一无二的战斗风格，在压迫与释放之间找到你的节奏。

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 俯视角动作射击 / Roguelike 构筑 |
| **Platform** | PC (Steam) |
| **Target Audience** | 挑战型动作玩家（见玩家画像） |
| **Player Count** | 单人 |
| **Session Length** | 20-40 分钟 / 局 |
| **Monetization** | 买断制 |
| **Estimated Scope** | 小型（4-8 周，单人） |
| **Comparable Titles** | Alien Shooter 2（俯视角敌潮射击）、死亡细胞（Roguelike 构筑 + 像素）、绝地潜兵 2（大规模敌群压迫感） |

---

## Core Fantasy

> 万军之中，刀尖起舞。你不是靠数值碾压敌人——你靠的是每一次精准闪避积攒的能量、每一次极限时机触发的时间缩放、以及亲手构筑的技能组合。当屏幕上 50+ 敌人同时向你冲来，你闪避、充能、爆发——那一瞬间，你是不可阻挡的。

---

## Unique Hook

> 类似 Hotline Miami 的俯视角一击即死的紧张感，加上 Vampire Survivors 级别的大规模敌潮，**再加上** 闪避不只是防御——它是你的核心进攻资源。每一次闪避都在为技能充能，每一次极限闪避都触发毁灭性的反击。

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Challenge** | 1 | 无限波次难度递增 + 闪避充能操作深度 + 构筑决策压力 |
| **Sensation** | 2 | 像素粒子命中特效 + 屏幕震动 + 极限闪避时间缩放 + 技能爆发清屏 |
| **Discovery** | 3 | 每局 Roguelike 升级随机组合，探索不同构筑方向 |
| **Fantasy** | 4 | 孤胆英雄对抗外星入侵的经典设定 |
| **Narrative** | N/A | 仅简单开场背景介绍，不做叙事驱动 |
| **Fellowship** | N/A | 纯单人游戏 |
| **Expression** | N/A | 构筑选择提供有限的自定义空间，但不是核心 |
| **Submission** | N/A | 高强度注意力需求，与放松体验相反 |

### Key Dynamics (Emergent player behaviors)

- 玩家会在闪避充能见底时主动寻找极限闪避时机，而不是被动等待恢复
- 玩家会根据拿到的升级选择调整战斗风格："这把走技能爆发流" vs "这把走闪避反击流"
- 极限闪避 + 时间缩放 + 技能爆发的连锁反应会形成高度上瘾的正反馈循环
- 玩家会在高波次中学会"管理闪避充能"而不是无脑按下闪避键

### Core Mechanics (Systems we build)

1. **闪避充能系统**：有限闪避次数（如 3 次），随时间缓慢恢复。普通闪避消耗充能，极限闪避不消耗 + 额外奖励
2. **双技能系统**：技能 1（时间冷却，闪避缩短 CD）+ 技能 2（极限闪避直接触发）
3. **Roguelike 构筑**：每波结束后 3 选 1 升级，构筑每局独特的战斗风格
4. **无限波次**：敌人数量、种类、强度随波次递增，形成压迫-释放的节奏循环
5. **受击次数血量**：血量 = 可承受攻击次数，闪避成功恢复血量，操作 = 生存

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | 每局的构筑选择决定了不同的战斗风格，玩家控制自己的成长方向 | Supporting |
| **Competence** | 闪避时机精度的提升、波次记录的突破、构筑理解的加深 —— 玩家清晰地感受到自己"变强了" | Core |
| **Relatedness** | 单人游戏，无社交系统。唯一的情感连接是对抗外星入侵的设定 | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers**（成就、收集、进度）— How: 波次里程碑、解锁新武器和技能、跨局进度系统
- [x] **Explorers**（探索系统、发现组合）— How: Roguelike 升级的随机组合鼓励实验和发现
- [ ] **Socializers**（社交、合作）— How: 不适用，纯单人体验
- [x] **Killers/Competitors**（挑战、排行）— How: 无限波次的难度曲线本身就是竞技场，排行榜可能作为 Tier 3 内容

### Flow State Design

- **Onboarding curve**：第 1 波少量慢速敌人，教会基础射击和普通闪避。第 2 波引入极限闪避提示。第 3 波引入技能系统
- **Difficulty scaling**：敌人数量递增 + 新敌人类型逐波解锁 + 敌人速度/血量微增
- **Feedback clarity**：极限闪避 = 时间缩放 + 音效 + 充能条高亮；技能就绪 = 屏幕边缘光效 + 音效
- **Recovery from failure**：死亡后立即显示本局统计 + 升级解锁进度，一键开始下一局（< 5 秒）

---

## Core Loop

### Moment-to-Moment (30 seconds)

射击清理杂兵 → 观察敌人攻击前摇 → 闪避（充能技能 + 可能回血）→ 技能爆发清场 → 重复

**满足感链条**：
- 射击：像素粒子命中特效 + 敌人受击闪烁
- 闪避（普通）：消耗充能 → 充能条减少，决策压力
- 极限闪避（完美时机）：时间缩放 + 镜头微震 + 充能条高亮 + 不消耗充能
- 技能释放：大范围像素粒子爆炸 → 屏幕边缘光效 → 积压的紧张感瞬间释放

### Short-Term (5 minutes)

清完一波敌群 → 3 选 1 升级选择（强化普攻 / 增强技能 / 改善闪避 / 解锁新能力）→ 下一波更强敌人 → 循环

**"再来一波"心理**：刚拿到的升级还没爽够，自然想继续

### Session-Level (20-40 minutes)

一场完整 Run：从初始状态开始 → 逐波构筑 → 在某一波死亡或主动结束。结算：本局数据 + 跨局进度点数

### Long-Term Progression

跨局解锁：新武器类型、新技能类型、新增升级选项加入随机池。从"勉强撑过 5 波"到"轻松碾压 15 波"

### Retention Hooks

- **Mastery**：闪避时机的精进、波次记录的突破
- **Investment**：跨局解锁进度保留
- **Curiosity**：未尝试过的构筑组合、未解锁的武器和技能

---

## Game Pillars

### Pillar 1: 闪避即武器

> 闪避不只是保命——它是有限资源、进攻引擎和操作检验的统一体。有限的充能次数让每一次闪避都是一次资源决策；精准的极限闪避同时做到躲避、回血、充能技能、不耗充能。

*Design test*：如果考虑增加"自动闪避"或"无限闪避"机制，这个支柱说：不行，闪避必须是受管理的有限资源。

### Pillar 2: 每一枪都要有感觉

> 像素粒子飞溅、屏幕震动、敌人受击反馈——无论是普通射击还是技能爆发，按下扳机的瞬间必须有物理上的满足感。反馈密度 = 游戏的核心竞争力。

*Design test*：如果一个武器的数值合理但射击反馈平淡，这个支柱说：别加这把武器，先修反馈。

### Pillar 3: 构筑决定命运

> 每局的升级选择塑造了截然不同的战斗风格。"这次我要成为什么样的战士"——不是"哪个选项更强"，而是"哪个方向更契合我想玩的风格"。

*Design test*：如果某个升级选项 90% 的玩家都会选，这个支柱说：它需要和另一个选项形成真正的取舍。

### Pillar 4: 压迫与释放

> 屏幕上的敌群数量本身就是一种压迫感，然后在技能爆发的瞬间全部释放。节奏不是平的——紧张积累到临界点，然后一次性宣泄。

*Design test*：如果一场战斗中敌人数量少于 10 个，这个支柱说：不够，加。

### Anti-Pillars (What This Game Is NOT)

- **NOT 叙事驱动**：没有长对话、没有过场动画、没有剧情分支。开场一段简单背景介绍后就是纯粹的战斗。叙事会让玩家停下来，而停下来是这个游戏最大的敌人。
- **NOT 精确瞄准**：没有爆头判定、不要求像素级精准。这是动作操作游戏，不是竞技 FPS。闪避时机才是核心技能检验。
- **NOT 资源囤积**：不捡弹药、不囤血包。子弹无限，生存靠操作，不靠背包管理。资源管理会打断战斗节奏。
- **NOT 慢节奏探索**：没有迷宫、没有解谜、没有分支路线。从头到尾就是战斗——任何让玩家停下来思考"该走哪条路"的设计都会破坏压迫与释放的节奏。

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| 绝地潜兵 2 | 大规模敌群压迫感、范围打击清场的爽快、战斗氛围 | 俯视角像素风格、闪避为核心的个体操作、Roguelike 构筑 | 验证了"大规模敌潮 + 单人/小队策略"的市场吸引力 |
| 死亡细胞 | Roguelike 构筑系统、流畅像素动作、闪避操作深度 | 俯视角射击而非横版近战、技能充能机制替代武器切换 | 验证了 Roguelike + 流畅动作 + 像素风格 = 千万级可能性 |
| 绝区零 | 极限闪避的时间缩放反馈、冲击感、镜头语言 | 用像素粒子而非 3D 特效、射击为主而非近战 | 验证了"闪避 → 正反馈"在动作游戏中的核心地位 |
| Alien Shooter 2 | 俯视角射击视角、大规模敌群、RPG 成长元素 | Roguelike 构筑替代线性升级、闪避充能替代站桩输出 | 验证了俯视角敌潮射击这一品类的存在价值 |

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 不限 |
| **Gaming experience** | 中硬核 — 有动作游戏基础，愿意挑战操作上限 |
| **Time availability** | "来一局" 型玩家，单次 20-40 分钟 |
| **Platform preference** | PC / Steam |
| **Current games they play** | 死亡细胞、Hades、Vampire Survivors、绝区零 |
| **What they're looking for** | 高反馈密度的操作体验、即时满足、可重复游玩 |
| **What would turn them away** | 糟糕的打击感、过长的加载时间、强制教程、慢节奏叙事 |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | 待定 — 运行 `/setup-engine` 根据概念和平台决策 |
| **Key Technical Challenges** | 大规模敌人 + 粒子特效的性能优化；极限闪避时机判定的精确性 |
| **Art Style** | 2D 像素 — 角色清晰可辨 + 细小像素粒子特效 |
| **Art Pipeline Complexity** | 低 — 像素风格可程序化生成大量特效，角色资产可复用 |
| **Audio Needs** | 中度 — 射击音效、闪避音效、敌人音效为核心；背景音乐辅助氛围 |
| **Networking** | 无 — 纯单机 |
| **Content Volume** | MVP：1 个角色、3 种敌人、12 个升级、无限波次 |
| **Procedural Systems** | 无程序化地图生成；Roguelike 升级选择为随机池抽选 |

---

## Risks and Open Questions

### Design Risks
- **核心循环的疲劳阈值**：高强度无间断战斗可能在 20 分钟后产生疲劳感。应对：技能爆发作为"呼吸点"，每波结束的升级选择作为自然暂停
- **闪避充能数量**：充能次数过多则失去资源管理的紧张感，过少则让玩家不敢主动操作。需要原型测试找到最佳值

### Technical Risks
- **大规模敌人 + 粒子特效性能**：同屏 50+ 敌人 + 持续粒子特效可能超出 2D 引擎的基础性能。应对：敌人对象池 + 粒子池 + 设置同屏上限

### Market Risks
- **品类饱和**：俯视角 Roguelike 是一个拥挤的赛道。靠闪避充能的独特操作深度和像素反馈密度来区分

### Scope Risks
- **Roguelike 平衡性**：需要大量手动测试和调整。MVP 仅 12 个升级，手动可管理
- **首款游戏的开发学习成本**：引擎学习、资产制作、音效设计都有学习曲线

### Open Questions
- 闪避充能的最佳初始值是多少？（3 次？4 次？— 原型测试确定）
- 极限闪避的判定窗口应该多宽？（原型测试 + 手感调优）
- 技能爆发的最佳频率是多少？（目标是每 15-30 秒一次大爆发）

---

## MVP Definition

**Core hypothesis**：玩家在"普通射击 → 闪避充能 → 技能爆发"的循环中，会因为操作反馈密度和 Roguelike 构筑的多样性，持续游玩超过 10 局。

**Required for MVP**:
1. 45 度俯视角场景 + 1 个可操作角色 + 像素美术风格
2. 1 种普通攻击（基础枪械，无限子弹）
3. 闪避充能系统（有限次数 + 时间恢复 + 普通/极限两种判定）
4. 技能 1（时间冷却，闪避成功缩短 CD）
5. 技能 2（极限闪避触发，自动反击/冲击）
6. 受击次数血量系统 + 闪避回血
7. 3 种基础敌人类型
8. 无限波次系统（难度递增）
9. 8-12 个升级选项（每波结束后 3 选 1）
10. 跨局进度解锁系统
11. 基础像素粒子特效（命中、闪避、技能、受击）
12. UI：血量、闪避充能、技能冷却、波次计数、升级选择界面
13. 基础音效（射击、闪避、技能、敌人受击）

**Explicitly NOT in MVP** (defer to later):
- Boss 敌人
- 多角色选择
- 排行榜和成就系统
- 控制器支持
- 多语言本地化

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 角色、3 敌人、12 升级 | 核心战斗循环 + 基础构筑 | 2-4 周 |
| **Vertical Slice** | 5 敌人、3 武器、3 技能类型 | 完整跨局进度 + 构筑深度 | +1-2 周 |
| **Full Vision** | Boss、多种武器/技能、成就 | 排行榜 + 控制器支持 + 音效完善 | +2-3 周 |

---

## Next Steps

- [ ] 配置引擎和版本参考文档 — `/setup-engine`
- [ ] 创建视觉风格规范 — `/art-bible`（在写 GDD 之前做，视觉风格影响技术架构决策）
- [ ] 验证概念完整性 — `/design-review design/gdd/game-concept.md`
- [ ] 拆解概念为独立系统 — `/map-systems`
- [ ] 为每个系统编写 GDD — `/design-system [system-name]`
- [ ] 产出主架构蓝图 — `/create-architecture`
- [ ] 记录关键技术决策 — `/architecture-decision`
- [ ] 验证进入生产阶段 — `/gate-check`
- [ ] 构建核心玩法原型 — `/prototype [core-mechanic]`
- [ ] 验证核心假设 — `/playtest-report`
- [ ] 规划首个冲刺 — `/sprint-plan new`
