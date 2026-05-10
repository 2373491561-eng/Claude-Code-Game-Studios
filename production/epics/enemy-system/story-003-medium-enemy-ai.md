# Story 003: 中型敌人 AI（距离保持 + 射击 + 墙角速射）

> **Epic**: enemy-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/enemy-system.md`
**Requirement**: `TR-enemy-001`
**ADR Governing Implementation**: ADR-0004: Enemy Manager
**ADR Decision Summary**: 中型敌人保持 150-200px 距离（滞后区间 [140,210]），撤退 180px/s，靠近 120px/s。攻击：250ms 前摇 → 发射子弹（150px/s, Area2D, 600px 射程），冷却 1.5-2.0s。撤退被障碍物阻挡 >0.3s → 速射模式（3 发，间隔 150ms）。受击硬直 50ms。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: 状态机使用 `Time.get_ticks_msec()`；子弹 Area2D（非 CharacterBody2D）
- Forbidden: 不要为每个中型敌人创建独立节点（由 EnemyManager 统一管理）

---

## Acceptance Criteria

- [ ] 中型敌人：32-48px 尺寸，HP=3，碰撞半径 16-24px
- [ ] 距离 >210px → 靠近 120px/s
- [ ] 距离 <140px → 撤退 180px/s（不可射击）
- [ ] 140-210px 滞后区间 → HOLD 状态，可射击
- [ ] 攻击：250ms 前摇 → 子弹 150px/s，冷却 1.5-2.0s（随机防同步）
- [ ] 子弹 Area2D，3×3px 纹理，最大飞行 600px（4s 后自毁）
- [ ] 撤退被阻挡 >0.3s → 速射 3 发（150ms 间隔）→ 横向平移绕障碍
- [ ] 受击：硬直 50ms + 白帧闪烁 2 帧
- [ ] 死亡：爆炸粒子 ~400ms → 移除

---

## Implementation Notes

滞后区间防止状态振荡：
```gdscript
if dist < 140: state = RETREAT
elif dist > 210: state = APPROACH
else: state = HOLD  # [140, 210]
```
70px 缓冲区确保进入 RETREAT 后不会立即弹回 APPROACH。

---

## QA Test Cases

- 距离保持：150-200px 稳定（进入此范围后停止靠近）
- 射击前摇：250ms 后子弹出现（枪口蓄能闪烁可视反馈）
- 墙角：撤退被墙挡 0.3s → 连射 3 发 + 横向平移
- 硬直：受击后 50ms 不移动不攻击

## Test Evidence: `tests/unit/enemy/medium_ai_test.gd`
## Dependencies

- Depends on: Story 001, Story 002 (separation grid)
- Unlocks: Story 004 (all enemy types together)
