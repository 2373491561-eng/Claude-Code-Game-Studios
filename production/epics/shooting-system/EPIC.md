# Epic: 射击系统

> **Layer**: Core
> **GDD**: design/gdd/shooting-system.md
> **Architecture Module**: ShootingSystem
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created — run `/create-stories shooting-system`

## Overview

实现即时命中（hitscan）射击——鼠标左键按住按射速间隔（8 发/秒，125ms）连续射击。使用手动射线-圆相交检测（ADR-0004 `check_bullet_hit()`），命中第一个敌人造成伤害。无限子弹，无需换弹。像素弹道线（1px 亮色，2 帧）从枪口延伸至命中点。闪避期间射击暂停，结束后自动恢复。skill_2 窗口内自动附加伤害×2 + 穿透 1（ADR-0010）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Enemy manager | Manual `check_bullet_hit()` for hitscan detection | LOW |
| ADR-0010: Skill_2 pierce | Double manual pass for pierce in one physics frame | LOW |
| ADR-0005: Event/signal | `EventBus.bullet_hit` for VFX + audio triggers | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-shoot-001 | Hitscan 8 发/秒，125ms 间隔 | ADR-0010 ✅ |
| TR-shoot-002 | skill_2 穿透（伤害×2 + 穿透 1 目标） | ADR-0010 ✅ |

## Definition of Done

- 鼠标左键按住按 8/s 射速连续射击
- 手动射线-圆相交命中检测正确（O(N)，53 敌人 <0.05ms）
- 命中第一个敌人造成伤害（最近者优先）
- 未命中显示弹道线到射程终点
- 闪避期间射击暂停，结束后自动恢复
- skill_2 窗口内双倍伤害 + 穿透 1（双射线）
- 射速间隔内松开再按下重置计时器
- 已死亡敌人不鞭尸
- 所有验收标准通过测试

## Next Step

Run `/create-stories shooting-system` to break this epic into implementable stories.
