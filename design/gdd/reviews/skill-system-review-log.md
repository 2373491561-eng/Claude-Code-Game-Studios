# Skill System — Review Log

## Review — 2026-05-08 — Verdict: MAJOR REVISION NEEDED (revised same session)
Scope signal: L
Specialists: game-designer, systems-designer, gameplay-programmer, godot-gdscript-specialist, qa-lead, creative-director
Blocking items: 3 (all resolved in revision) | Recommended: 7 | Nice-to-Have: 4

Summary: 首次审查。8 个必选章节完整，7 个依赖 GDD 全部存在。3 个致命阻塞项：(1) 充能门控未传播——闪避 v2 已 Approved 但技能 GDD 所有引用仍为无条件版本；(2) 无机械层面「蓄」阶段——Pillar 4 的「积蓄后爆发」幻想缺乏机械表达，冷却速度与闪避充能零关联；(3) 取消陷阱——闪避取消技能后全额 CD 损失，对按设计使用的玩家施加惩罚。creative-director 裁决 MAJOR REVISION NEEDED——核心冲击波幻想保留，但「蓄」的机械表达必须从零搭建。

Same-session revision applied: 冷却速度与充能挂钩（cd_speed = 1.0 + (charge-1)×0.5）、取消退还 75% CD（仅前 200ms 可取消）、skill_2 改为手动触发窗口、冷却改为真实时间（Time.get_ticks_msec()）、AoE 量化为圆形 200px 伤害=1、skill_2 基础效果伤害×2+穿透 1、充能球 4 状态阈值定义、CD 缩减上限 60%。AC 从 6 条扩展至 17 条，边缘情况从 5 条扩展至 13 条，调优参数从 4 项扩展至 13 项。重新审查建议：/design-review design/gdd/skill-system.md --depth full。

Prior verdict resolved: First review

---

## Review — 2026-05-08 — Verdict: APPROVED (after same-session revision)
Scope signal: L
Specialists: game-designer, systems-designer, godot-gdscript-specialist, qa-lead, audio-director, ux-designer, creative-director
Blocking items: 5 (all resolved in revision) | Recommended: 10 | Nice-to-Have: 4

Summary: Re-review of v2 after prior MAJOR REVISION NEEDED. v2 improvements (charge-accelerated cooldown, cancel refund, real-time CD, 60% cap) confirmed sound. 5 new blocking items found — all integration/consistency issues, not fundamental design errors: (1) skill_2 reverted from manual to auto-attach — resolves 5 cross-GDD staleness problems; (2) cd_speed formula clamped to min 1.0 at charge=0; (3) charge orb visual "ready" threshold corrected from ≤5% to =0% (orb no longer lies); (4) same-frame cancel priority established; (5) input processing consolidated to _physics_process. All 5 resolved in same-session revision. creative-director verdict: APPROVED — core design sound, specification precise enough for implementation.

Prior verdict resolved: Yes (MAJOR REVISION NEEDED from earlier today)
