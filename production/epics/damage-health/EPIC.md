# Epic: 伤害与血量

> **Layer**: Core
> **GDD**: design/gdd/damage-health.md
> **Architecture Module**: DamageHealthSystem
> **Status**: Ready
> **Manifest Version**: 2026-05-10
> **Stories**: Not yet created — run `/create-stories damage-health`

## Overview

实现伤害与血量系统——玩家 HP 制（最大 3 点），受击扣减取决于敌人类型（小型/中型 1 点，大型 2 点）。受击后 500ms 无敌帧。极限闪避（充能≥1）回血 1 + 护盾 1（3s 真实时间）。护盾优先消耗：完全吸收不触发无敌帧，穿透部分触发。HP=0 → 死亡冻结 500ms → 切换到死亡结算场景。敌人受击：基础伤害 1 + 构筑加成 + skill_2 倍率。与闪避系统通过接口解耦（`is_invincible()` / `get_charge_count()`）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Real-time timing | Iframes 500ms + shield 3s + death freeze 500ms all real-time | LOW |
| ADR-0005: Event/signal | `EventBus.player_hit` / `player_death` for VFX/audio/camera | LOW |
| ADR-0007: Perfect dodge | Healing + shield triggered by perfect dodge (charge≥1 only) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-dmg-001 | HP 3 + 无敌帧 500ms + 护盾 3s（优先消耗） | ADR-0001 ✅ |
| TR-dmg-002 | 大型敌人伤害=2，小型/中型=1 | ADR-0001 ✅ |

## Definition of Done

- 玩家 HP=3，受击扣减正确（小型/中型=1，大型=2）
- 受击后 500ms 无敌帧，不受 time_scale 影响
- 无敌帧内受击=0 伤害、护盾不消耗
- 极限闪避（充能≥1）回血 1 + 护盾 1（3s 真实时间）
- 护盾优先消耗：全吸收不触发无敌帧，穿透触发
- 大型敌人 2 点伤害 vs 1 护盾：护盾吸收 1 + HP-1 + 触发无敌帧
- HP=0 死亡冻结 500ms → 切换到死亡结算
- 死亡优先于回血（HP=0 时极限闪避不回血）
- 敌人受击伤害管道正确（基础 + 构筑 + skill_2 倍率）
- 闪避触发帧优先于伤害帧
- 所有 20 个 AC 通过测试

## Next Step

Run `/create-stories damage-health` to break this epic into implementable stories.
