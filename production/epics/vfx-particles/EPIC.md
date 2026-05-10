# Epic: VFX/粒子特效

> **Layer**: Presentation
> **GDD**: design/gdd/vfx-particles.md
> **Architecture Module**: VFXManager
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created

## Overview

实现像素粒子特效系统——8 个预分配粒子池（弹道线/命中火花/闪避残影/爆发冲击波/爆发核心/死亡碎裂/环境孢子/化学蒸汽），总计 504 粒子。GPU 粒子模式，LRU 回收。800 粒子峰值 ≤4.17ms。屏幕效果：暗角(20-60%)、冷色滤镜、时间缩放视觉。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0013: VFX particle pool | 8 pools, pre-alloc, GPU mode, LRU recycle | MEDIUM |
| ADR-0005: Event/signal | EventBus trigger connections for all VFX | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-vfx-001 | 预分配粒子池，不动态创建/销毁 | ADR-0013 ✅ |
| TR-vfx-002 | 800 粒子峰值 ≤4.17ms | ADR-0013 ✅ |
| TR-vfx-003 | 暗角 + 冷色滤镜 + 边缘锐化 | ADR-0009 ✅ |

## Definition of Done

- 8 个粒子池正常工作
- EventBus 信号驱动粒子生成
- 技能爆发 800 粒子峰值 ≤4.17ms
- 暗角跟随战斗状态变化
- 极限闪避冷色滤镜
- 所有验收标准通过（Visual/Feel 用截图验证）

## Next Step

Run `/create-stories vfx-particles`
