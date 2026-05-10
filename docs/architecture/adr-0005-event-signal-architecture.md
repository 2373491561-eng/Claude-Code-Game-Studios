# ADR-0005: Event/Signal Architecture

## Status
Accepted

## Date
2026-05-08

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — Godot signals are in training data (4.0+) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (timing), ADR-0002 (input), ADR-0004 (enemy manager) |
| **Enables** | All Presentation layer systems (VFX, Audio, UI) |
| **Blocks** | Feature layer (wave, build) — need event channel definitions |
| **Ordering Note** | Signal definitions must exist before Presentation implementation |

## Context

### Problem Statement
游戏有 6 个 Core 系统发射事件，4 个 Foundation 系统 + 5 个 Presentation 系统需要响应事件。如果系统之间直接调用方法，会形成网状依赖——闪避系统直接调用 VFX 系统的方法、直接调用音频系统的方法、直接调用摄像机的方法。测试和重构困难，系统耦合紧密。

架构文档第 5 条原则："Signal-up, call-down." Core 系统通过信号向上通知 Presentation 系统，不直接调用它们的方法。

### Constraints
- Godot 4.6.2 内置信号系统（`signal` 关键字 + `emit()` + `connect()`）
- 全局事件总线（EventBus Autoload）可用于跨系统信号
- Presentation 层系统尚未审查（VFX、音频、HUD 等）——信号接口需要预定义

### Requirements
- Core 系统不直接调用 Presentation 系统
- 同一事件可被多个消费者接收（VFX + 音频 + 摄像机同时响应技能爆发）
- 信号签名类型安全
- 新 Presentation 系统可在不改 Core 代码的情况下添加

## Decision

**使用全局 EventBus Autoload 承载跨系统信号。Core 系统通过 EventBus 发射信号，Presentation 系统通过 EventBus 连接信号。**

```
EventBus (Autoload)
├── dodge_perfect(pos, charge_count)     ← DodgeSystem emits
├── dodge_normal(pos, direction)         ← DodgeSystem emits
├── skill_1_cast(pos)                    ← SkillSystem emits
├── skill_2_triggered()                  ← SkillSystem emits
├── player_hit(damage, source_pos)       ← DamageHealthSystem emits
├── player_death(stats)                  ← DamageHealthSystem emits
├── enemy_killed(type, pos)              ← EnemySystem emits
├── enemy_spawned(type, pos)             ← EnemySystem emits
├── bullet_hit(hit_pos, is_skill2)       ← ShootingSystem emits
├── wave_start(wave_num)                 ← WaveManager emits
├── wave_clear(wave_num)                 ← WaveManager emits
├── upgrade_selected(upgrade_id)         ← BuildSystem emits
└── game_paused() / game_resumed()       ← SceneManager emits
```

### 连接模式

```gdscript
# --- Core 系统：发射信号 ---
# DodgeSystem
func _execute_perfect_dodge() -> void:
    # ... 游戏逻辑 ...
    EventBus.dodge_perfect.emit(global_position, charge_count)
    # DodgeSystem 不知道谁会接收——不依赖 VFX/Audio/Camera

# --- Presentation 系统：连接信号 ---
# VFXSystem._ready():
EventBus.dodge_perfect.connect(_on_perfect_dodge)
EventBus.skill_1_cast.connect(_on_skill_cast)

# AudioSystem._ready():
EventBus.dodge_perfect.connect(_on_perfect_dodge_audio)
EventBus.skill_1_cast.connect(_on_skill_cast_audio)
```

### 调用方向规则

| 方向 | 模式 | 示例 |
|------|------|------|
| Core → Core | 直接方法调用（接口） | `dodge_system.get_charge_count()` |
| Core → Foundation | 直接方法调用 | `input_system.get_move_axis()` |
| Core → Presentation | **信号（通过 EventBus）** | `EventBus.dodge_perfect.emit()` |
| Presentation → Core | 禁止（单向依赖） | — |

## Alternatives Considered

### Alternative 1: 直接方法调用
- **Pros**: 简单、类型安全、IDE 自动补全
- **Cons**: Core 依赖 Presentation（反向依赖）。添加新 Presentation 系统需要改 Core 代码。测试 Core 需要 mock Presentation
- **Rejection Reason**: 违反架构原则——Core 不应知道 Presentation 的存在

### Alternative 2: Godot 节点信号（无 EventBus）
- **Pros**: 使用引擎原生功能
- **Cons**: 信号连接需要节点引用——Core 需要知道 Presentation 节点路径。场景树变更会断开连接
- **Rejection Reason**: 与节点路径耦合。跨场景信号需要额外处理

## Consequences

### Positive
- Core 系统零 Presentation 依赖——可独立测试
- 新 Presentation 系统只需连接 EventBus——不影响现有代码
- 信号签名集中定义——容易检查完整性
- 同一事件可被任意数量的系统消费（VFX + Audio + Camera 同时响应）

### Negative
- EventBus 是全局对象——信号列表随时间增长，维护需要纪律
- 信号连接错误在编译时不报错（Godot 信号是运行时连接）
- Presentation 系统启动顺序：必须晚于 EventBus Autoload

### Risks
- **信号泛滥**：每个小事件都变成信号，EventBus 膨胀。缓解：只发射跨系统事件。系统内部事件留在系统内
- **已弃用信号不清除**：从 EventBus 删除信号可能断开未知消费者。缓解：弃用时保持信号存在 2 个 sprint，打印警告，再删除

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| dodge-system.md | 极限闪避 → VFX + 音频 + 摄像机 | EventBus.dodge_perfect 被 3 个 Presentation 系统消费 |
| skill-system.md | 技能爆发 → VFX 冲击波 + 音频 Ducking + 摄像机震动 | EventBus.skill_1_cast |
| damage-health.md | 受击 → VFX + 音频 + 摄像机 | EventBus.player_hit |
| shooting-system.md | 命中 → VFX 命中粒子 + 命中音效 | EventBus.bullet_hit |
| enemy-system.md | 敌人死亡 → VFX + 音效 | EventBus.enemy_killed |

## Performance Implications
- **CPU**: 信号发射 O(1) per connected callback。每个事件 2-4 个消费者 → 忽略不计
- **Memory**: EventBus 对象 ~2KB
- **Load Time**: 无影响（Autoload 在引擎启动时加载）

## Validation Criteria
- Core 系统代码中无 `$VFXSystem` 或 `get_node("AudioSystem")` 引用
- 技能 1 释放：VFX + Audio + Camera 在 1 帧内响应
- 断开 VFX 的连接后：游戏逻辑正常运行（仅视觉效果缺失）
