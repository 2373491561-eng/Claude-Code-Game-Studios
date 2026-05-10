# Epic: 敌人系统

> **Layer**: Core
> **GDD**: design/gdd/enemy-system.md
> **Architecture Module**: EnemySystem (EnemyManager)
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created — run `/create-stories enemy-system`

## Overview

实现集中式敌人管理器——Struct-of-Arrays 数据布局，53 敌人峰值（40 小型/10 中型/3 大型）统一 AI 更新循环。3 种状态机：小型直线追逐+接触伤害，中型距离保持+远程射击，大型缓慢推进+冲锋+近战。手动碰撞检测（无物理体节点），空间哈希分离 steering，MultiMeshInstance2D 批量渲染小型敌人。死亡 VFX 与碰撞体移除解耦（5-10/帧延迟移除）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Enemy manager | Struct-of-arrays, manual collision, MultiMesh, deferred removal | LOW |
| ADR-0003: Physics 60Hz | Spatial hash grid (32px cells), 60Hz physics update | LOW |
| ADR-0001: Real-time timing | State machine timers via `Time.get_ticks_msec()` | LOW |
| ADR-0005: Event/signal | `EventBus.enemy_killed` / `enemy_spawned` for VFX/audio | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-enemy-001 | 3 种状态机（小/中/大）+ 前摇动画 | ADR-0004 ✅ |
| TR-enemy-002 | 集中式管理器 + 数组统一更新 | ADR-0004 ✅ |
| TR-enemy-003 | MultiMesh 仅小型，中/大型 Sprite2D | ADR-0004 ✅ |
| TR-enemy-004 | 流场寻路 + 空间哈希分离（32px 单元） | ADR-0003, ADR-0004 ✅ |
| TR-enemy-005 | 物理 60Hz + 渲染 240fps | ADR-0003 ✅ |

## Definition of Done

- Struct-of-arrays 数据布局（positions/velocities/states/timers/hp）
- 3 种状态机完整实现（小型追逐+冷却/中型距离保持+速射/大型冲锋+近战）
- 手动射线-圆相交（`check_bullet_hit`）和接触伤害检测（`check_player_contact`）
- 空间哈希分离（32px 单元，~200 次检查 vs O(N²) 780 次）
- MultiMeshInstance2D 渲染 40 小型敌人（1 draw call）
- Sprite2D 池渲染 10 中型 + 3 大型
- 死亡移除延迟（5-10/帧）
- 生成交错（5-10/帧）+ 100-200ms 淡入
- 中型墙角速射模式
- 大型冲锋可被闪避躲开
- 玩家死亡时所有敌人 AI 冻结
- 53 敌人全活跃帧时间 ≤4.17ms
- 所有 15 个 AC 通过测试

## Next Step

Run `/create-stories enemy-system` to break this epic into implementable stories.
