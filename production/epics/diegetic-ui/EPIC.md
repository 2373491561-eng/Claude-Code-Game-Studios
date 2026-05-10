# Epic: Diegetic UI

> **Layer**: Presentation
> **GDD**: design/gdd/diegetic-ui.md
> **Architecture Module**: DiegeticUI
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created

## Overview

实现角色身上直接显示的战斗信息层——血量光环（圆形分段环 20px 半径）、技能充能球（12-14px 四态）、闪避光点（3×3px 菱形 28px 轨道）。遵循美术圣经 §7 完整定义，不依赖屏幕 HUD。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Event/signal | EventBus 驱动状态更新 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-diegetic-001 | 血量光环段数 + 受击碎裂 + 回血渐亮 | ADR-0005 ✅ |
| TR-diegetic-002 | 技能充能球四态（灰蓝→冷青→电光蓝→橙红） | ADR-0005 ✅ |
| TR-diegetic-003 | 闪避光点（冷青脉冲=可用, 灰蓝=冷却） | ADR-0005 ✅ |

## Definition of Done

- 血量光环正确渲染（段数=HP，受击碎裂动画，回血渐亮）
- 充能球四态颜色+脉动频率正确
- 闪避光点数量=充能数，颜色正确
- 所有元素 z_index 正确（渲染层级不冲突）
- 所有验收标准通过（Visual/Feel 用截图验证）

## Next Step

Run `/create-stories diegetic-ui`
