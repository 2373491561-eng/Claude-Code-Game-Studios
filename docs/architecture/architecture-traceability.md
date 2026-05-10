# Architecture Traceability Index — 裂隙反应

Maps every Technical Requirement (TR) from the architecture document to the ADR that covers it.

| Req ID | System | Requirement | ADR Coverage | Status |
|--------|--------|-------------|--------------|--------|
| TR-input-001 | Input | 双通道闪避去抖+缓冲 | ADR-0002 | ✅ |
| TR-input-002 | Input | 输入统一 _physics_process | ADR-0002 | ✅ |
| TR-scene-001 | Scene | 3 场景流 | ADR-0006 | ✅ |
| TR-scene-002 | Scene | GameManager + AudioManager | ADR-0006 | ✅ |
| TR-audio-001 | Audio | 总线结构 + Ducking | ADR-0008 | ✅ |
| TR-audio-002 | Audio | 时间缩放音高 | ADR-0008 | ✅ |
| TR-cam-001 | Camera | 跟随+偏移+缩放 | ADR-0009 | ✅ |
| TR-cam-002 | Camera | 震动系统 | ADR-0009 | ✅ |
| TR-move-001 | Movement | WASD 300px/s | ADR-0002 | ✅ |
| TR-shoot-001 | Shooting | Hitscan 8/s | ADR-0010 | ✅ |
| TR-shoot-002 | Shooting | skill_2 穿透 | ADR-0010 | ✅ |
| TR-dodge-001 | Dodge | 充能+闪避 | ADR-0007 | ✅ |
| TR-dodge-002 | Dodge | 极限闪避检测 | ADR-0007 | ✅ |
| TR-dodge-003 | Dodge | time_scale=0.2 | ADR-0001, ADR-0007 | ✅ |
| TR-skill-001 | Skill | 技能1 CD+AoE | ADR-0001 | ✅ |
| TR-skill-002 | Skill | 技能2 自动附加 | ADR-0010 | ✅ |
| TR-skill-003 | Skill | 充能球 UI | ADR-0005 | ✅ |
| TR-dmg-001 | Damage | HP+无敌+护盾 | ADR-0001 | ✅ |
| TR-dmg-002 | Damage | 大型伤害=2 | ADR-0001 | ✅ |
| TR-enemy-001 | Enemy | 状态机+前摇 | ADR-0004 | ✅ |
| TR-enemy-002 | Enemy | 集中式管理器 | ADR-0004 | ✅ |
| TR-enemy-003 | Enemy | MultiMesh 范围 | ADR-0004 | ✅ |
| TR-enemy-004 | Enemy | 流场+空间哈希 | ADR-0003, ADR-0004 | ✅ |
| TR-enemy-005 | Enemy | 物理 60Hz | ADR-0003 | ✅ |
| TR-time-001 | Cross | Time.get_ticks_msec | ADR-0001 | ✅ |
| TR-time-002 | Cross | Tween.set_ignore_time_scale | ADR-0001 | ✅ |
| TR-build-001 | Build | damage pipeline | ADR-0010 | ✅ |
| TR-wv-001 | Wave | 无限波次+递增 | — | GAP |

## Coverage Summary

| Layer | Total TRs | Covered | Gaps |
|-------|:---------:|:-------:|:----:|
| Foundation | 8 | 8 | 0 |
| Core | 17 | 17 | 0 |
| Cross-system | 2 | 2 | 0 |
| Feature | 1 | 0 | 1 (wave — design-level only, no ADR needed) |
| **Total** | **28** | **27** | **1 (non-blocking)** |

Foundation layer: 0 gaps ✅
