# ADR-0001: Real-Time Timing Strategy

## Status
Accepted

## Date
2026-05-08

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — `Time.get_ticks_msec()` is in LLM training data (Godot 4.0+) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `Time.get_ticks_msec()` returns OS monotonic clock (not affected by `Engine.time_scale`) in Godot 4.6.2 — verified via official docs |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (input processing architecture), ADR-0003 (physics tick rate), ADR-0004 (enemy manager) |
| **Blocks** | None — all 10 Approved GDDs already use this pattern |
| **Ordering Note** | Foundation decision — must be Accepted before any Core system implementation begins |

## Context

### Problem Statement
《裂隙反应》的核心机制——极限闪避——使用 `Engine.time_scale = 0.2` 创造时间冻结效果。Godot 的 `_process(delta)` 和 `_physics_process(delta)` 中的 `delta` 参数受 `time_scale` 缩放：在 0.2 倍速下，`delta` 约为正常值的 1/5。如果技能冷却、无敌帧、护盾计时器等使用 `delta` 累计，极限闪避期间这些计时器会以 1/5 速度运行——15 秒技能冷却变成 75 秒真实时间，500ms 无敌帧变成 2.5 秒。这破坏了游戏的节奏和平衡。

项目中有 **6 个系统** 依赖精确的真实时间计时：闪避位移（300ms）、受击无敌帧（500ms）、技能 1 冷却（15s 基准）、技能 2 窗口（500ms）、护盾持续（3s）、死亡冻结（500ms）。它们必须不受 `Engine.time_scale` 影响。

### Constraints
- 240fps 渲染目标，60Hz 物理
- `Engine.time_scale` 用于极限闪避视觉效果（0.2 → ease-out 恢复）
- 摄像机震动同步使用 `Tween`，可通过 `set_ignore_time_scale(true)` 控制
- 音频系统不受 `time_scale` 影响（AudioServer 独立于引擎时间）

### Requirements
- 所有 gameplay 计时器以真实时间运行，不受 `Engine.time_scale` 影响
- 精度到毫秒级（技能 GDD 要求"四舍五入到 0.1s"）
- 不引入额外的单例或全局状态
- 与 Godot 4.6.2 原生 API 兼容

## Decision

**所有 gameplay 计时器使用 `Time.get_ticks_msec()` 作为时间源，不使用 `delta` 参数。**

`Time.get_ticks_msec()` 返回操作系统单调时钟的毫秒值，不受 `Engine.time_scale` 影响。计时器按照以下模式实现：

```gdscript
# 基于真实时间的冷却计时
var _cooldown_remaining: float = 0.0
var _last_tick_ms: int = 0

func _ready() -> void:
    _last_tick_ms = Time.get_ticks_msec()

func _process(_delta: float) -> void:
    var now_ms: int = Time.get_ticks_msec()
    var elapsed: float = (now_ms - _last_tick_ms) / 1000.0  # 转为秒
    _last_tick_ms = now_ms

    if _cooldown_remaining > 0.0:
        _cooldown_remaining -= elapsed * _cd_speed_multiplier
        _cooldown_remaining = max(_cooldown_remaining, 0.0)
```

### Architecture Diagram

```
┌───────────────────────────────────────────────┐
│  Time.get_ticks_msec()  ← OS Monotonic Clock │
│  (不受 Engine.time_scale 影响)                │
└───────────────┬───────────────────────────────┘
                │
    ┌───────────┼───────────┬──────────────┐
    ▼           ▼           ▼              ▼
 闪避位移   技能冷却    受击无敌帧    护盾/死亡
 (300ms)   (15s 基准)   (500ms)     冻结 (500ms)
    │           │           │              │
    └───────────┴───────────┴──────────────┘
                │
        使用 delta/PhysicsDelta
        仅用于视觉插值（移动、摄像机跟随）
```

### Key Interfaces

| 系统 | 计时器 | 实现方式 |
|------|--------|---------|
| DodgeSystem | 闪避位移 300ms | `Time.get_ticks_msec()` 追踪位移进度，`get_physics_process_delta_time()` 用于每帧位移步进 |
| SkillSystem | 技能 1 冷却 | `Time.get_ticks_msec()` 帧差 + `cd_speed_multiplier` |
| SkillSystem | 技能 2 窗口 500ms | `Time.get_ticks_msec()` 窗口开启/过期检测 |
| DamageHealthSystem | 受击无敌帧 500ms | `Time.get_ticks_msec()` 无敌帧结束检测 |
| DamageHealthSystem | 护盾持续 3s | `Time.get_ticks_msec()` 护盾过期检测 |
| DamageHealthSystem | 死亡冻结 500ms | `Time.get_ticks_msec()` 冻结→场景切换 |
| EnemySystem | 攻击冷却/前摇 | `Time.get_ticks_msec()` 状态机计时器 |
| CameraSystem | 震动衰减 | `Tween` + `set_ignore_time_scale(true)` |

**例外**：以下可以使用 `delta`（它们应该受 time_scale 影响）：
- 敌人移动（应该随世界减速）
- 子弹飞行（应该随世界减速）
- 摄像机跟随/偏移插值（视觉跟随，非 gameplay 计时）
- VFX 粒子动画

## Alternatives Considered

### Alternative 1: 纯 Delta-Based 计时
- **Description**: 所有计时器使用 `_process(delta)` 或 `_physics_process(delta)` 累加。`Engine.time_scale` 全局影响所有计时。
- **Pros**: 实现简单，无需手动追踪 last_tick；与 Godot 默认行为一致
- **Cons**: 极限闪避（time_scale=0.2）期间，15s 冷却变成 75s，500ms 无敌帧变成 2.5s，破坏游戏节奏
- **Rejection Reason**: 与核心机制（极限闪避）根本冲突。time_scale 是视觉效果工具，不应影响 gameplay 数值

### Alternative 2: 混合方案（部分用 delta，部分用 get_ticks_msec）
- **Description**: 技能冷却用真实时间，敌人计时用 delta。每个系统单独决定时间源。
- **Pros**: 灵活，可以逐系统调优
- **Cons**: 增加认知负担——程序员必须记住每个系统的时间域。容易出错（新系统默认用 delta 导致 bug）。两个时间域之间的交互（如技能冷却 vs 敌人行为）产生意外的时间错位
- **Rejection Reason**: 一致性 > 灵活性。统一的时间域策略消除整类 bug。项目规模（20 系统，单人）不需要混合方案的复杂度

## Consequences

### Positive
- 极限闪避的时间缩放不影响任何 gameplay 数值——视觉冻结只是视觉
- 所有计时器行为可预测：15 秒冷却永远 = 15 秒真实时间，无论屏幕上演什么
- 代码审查容易：任何使用 `delta` 累加计时的代码都是可疑的
- 状态机计时（敌人 AI）与玩家计时（技能冷却）在同一时间域，互相同步

### Negative
- 所有计时代码必须手动追踪 `last_tick_ms`，增加样板代码
- `_process()` 和 `_physics_process()` 中必须额外调用 `Time.get_ticks_msec()`
- 新贡献者可能不了解这个约定，默认使用 delta

### Risks
- **忘记使用真实时间的 bug**：某系统错误使用 delta，在 time_scale=0.2 时出现异常行为。缓解：代码审查检查点 + 测试用例覆盖 time_scale 场景
- **`Time.get_ticks_msec()` 回绕**：32 位毫秒值约 49.7 天回绕一次。单次 Run 最长 40 分钟，不受影响。缓解：使用差值计算（`now - last`），差值永远正确（无符号整数回绕的模运算特性）

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| dodge-system.md | 闪避位移 300ms 真实时间 | `get_physics_process_delta_time()` 用于步进，`Time.get_ticks_msec()` 追踪总时长 |
| skill-system.md | 技能 1 冷却 15s 真实时间，`cd_speed_multiplier` | `Time.get_ticks_msec()` 帧差 + 速度乘数 |
| skill-system.md | 技能 2 窗口 500ms 真实时间 | `Time.get_ticks_msec()` 窗口计时 |
| damage-health.md | 受击无敌帧 500ms 真实时间 | `Time.get_ticks_msec()` 无敌帧到期检测 |
| damage-health.md | 护盾持续 3s 真实时间 | `Time.get_ticks_msec()` 护盾过期检测 |
| damage-health.md | 死亡冻结 500ms 真实时间 | `Time.get_ticks_msec()` 冻结计时 |
| enemy-system.md | 敌人攻击冷却/前摇计时 | `Time.get_ticks_msec()` 状态机时间追踪 |

## Performance Implications
- **CPU**: `Time.get_ticks_msec()` 是系统调用包装，每次调用 ~100ns。每帧 ~10 次调用 = ~1μs。可以忽略不计
- **Memory**: 每个计时器存储一个 `int`（8 字节）。总内存开销 < 100 字节
- **Load Time**: 无影响
- **Network**: 不适用（单机游戏）

## Migration Plan
不适用——项目尚未开始编码。此 ADR 设置初始约定。

## Validation Criteria
- 在 `Engine.time_scale = 0.2` 下运行 10 秒：技能冷却减少 10 秒（不受缩放影响）
- 在 `Engine.time_scale = 0.2` 下受击：无敌帧在 500ms 真实时间后解除（不是 2.5 秒）
- 所有使用 delta 累加的代码必须有明确注释说明为什么不用 `Time.get_ticks_msec()`

## Related Decisions
- ADR-0002: Input Processing Architecture（输入处理也依赖 `_physics_process` 的统一时序）
- ADR-0003: Physics Tick Rate（物理 60Hz + 渲染 240fps 的分离）
- ADR-0004: Centralized Enemy Manager（敌人计时器使用相同的时间源）
