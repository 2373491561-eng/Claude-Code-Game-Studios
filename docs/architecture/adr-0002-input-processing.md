# ADR-0002: Input Processing Architecture

## Status
Accepted

## Date
2026-05-08

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Input |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `Input.is_action_just_pressed()` fires exactly once on the physics frame after `_input()` processing in Godot 4.6.2 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (real-time timing) |
| **Enables** | All Core system implementations |
| **Blocks** | None |
| **Ordering Note** | Must be Accepted before DodgeSystem and SkillSystem implementation — their frame-priority rules depend on this |

## Context

### Problem Statement
Godot 提供两个输入处理点：`_input(event)`（每个输入事件触发，可发生在物理帧之间）和 `_physics_process(delta)`（固定物理步长）。如果闪避触发在 `_input()` 中立即执行，而技能 1 触发在 `_physics_process()` 中检测，则技能 GDD v3 AC7 规定的"同帧取消优先"规则无法保证——因为 `_input()` 先于 `_physics_process()` 执行，闪避总是先于技能触发。

此外，4 个 Approved GDD（闪避、技能、伤害、输入）已经一致规定输入处理必须统一在 `_physics_process` 中。此 ADR 将该约定正式化为架构决策。

### Constraints
- 240fps 渲染 / 60Hz 物理（待 ADR-0003 确定）
- 双通道闪避（Shift + 右键）需要去抖（50ms 窗口）
- 输入缓冲窗口 100ms（允许在动作结束前提前按下）
- 闪避期间锁定移动和射击，但不锁定技能 1

### Requirements
- 闪避和技能 1 的同帧触发顺序必须有保证（取消优先）
- 去抖和缓冲必须基于真实时间（不受 `Engine.time_scale` 影响）
- 按住射击在闪避结束后自动恢复
- 与 Godot Input Map 系统兼容

## Decision

**所有游戏输入的动作执行（射击、闪避、技能）统一在 `_physics_process()` 中通过 `Input.is_action_just_pressed()` / `Input.is_action_pressed()` 检测和处理。`_input(event)` 仅用于去抖和缓冲的轻量状态标记。**

```gdscript
# _input(): 仅做轻量标记
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("dodge"):
        _dodge_raw_time_ms = Time.get_ticks_msec()
        _dodge_queued = true

# _physics_process(): 动作执行 + 优先级排序
func _physics_process(_delta: float) -> void:
    _process_dodge()   # 步骤 1: 闪避先处理（去抖 + 缓冲判定）
    _process_skill()   # 步骤 2: 技能后处理（同帧取消优先规则在此实现）
    _process_shoot()   # 步骤 3: 射击（最低优先级）

func _process_dodge() -> void:
    if not _dodge_queued:
        return
    var now = Time.get_ticks_msec()
    if now - _last_dodge_ms < DEBOUNCE_MS:  # 50ms 去抖
        _dodge_queued = false
        return
    if not dodge_system.can_dodge():
        if dodge_system.dodge_ending_soon():  # 100ms 缓冲
            _dodge_buffered = true
        _dodge_queued = false
        return
    # 执行闪避
    dodge_system.execute_dodge()
    _last_dodge_ms = now
    _dodge_queued = false
```

### 同帧优先级规则

```
if dodge_triggered and skill_1_triggered_on_same_frame:
    if skill_system.is_in_startup_phase():  # 0-200ms
        skill_system.cancel()              # 取消技能，退还 75% CD
    # 否则：两者均执行（技能 1 后 300ms 不可取消）
```

### Architecture Diagram

```
_input(event)                     _physics_process (60Hz)
─────────────                     ──────────────────────
   │                                    │
   ├─ dodge press → flag                ├─ 1. dodge: 去抖 → 缓冲 → 执行
   │                                    │      └─ 同帧取消检查
   │                                    ├─ 2. skill_1: is_action_just_pressed
   │                                    │      └─ 若 dodge 在同帧取消 → skip
   │                                    ├─ 3. shoot: is_action_pressed
   │                                    │      └─ 闪避中 → pause; 闪避结束 → resume
   │                                    └─ 4. move: get_vector (持续轮询)
```

## Alternatives Considered

### Alternative 1: `_input()` 中直接执行所有动作
- **Pros**: 原生 Godot 模式，代码简洁
- **Cons**: 无法保证同帧事件的处理顺序。`_input()` 中无法访问某些 `_physics_process` 中才更新的状态
- **Rejection Reason**: 技能 GDD AC7 要求同帧取消优先——这需要两个动作在同一处理阶段中按顺序执行

### Alternative 2: `_unhandled_input()` 处理游戏动作
- **Pros**: 与 UI 输入自然分离
- **Cons**: 去抖和缓冲逻辑与 GUI 的 `accept_event()` 交互复杂。同帧优先级问题与 Alternative 1 相同
- **Rejection Reason**: 不解决核心问题（同帧排序），增加 GUI/游戏输入分离的复杂度

## Consequences

### Positive
- 同帧事件顺序完全可控——AC7 自然实现
- 所有游戏输入在一个函数中处理，调试简单
- 物理步长一致 = 输入处理速率一致 = 无帧率依赖的 bug
- `_input()` 仅做标记 = 极轻量，不会因为复杂逻辑阻塞事件队列

### Negative
- 60Hz 物理下，输入响应延迟最坏情况 ~16.7ms（1 物理帧）——在 240fps 渲染下不可感知
- 每个需要输入的系统必须在 `_physics_process` 中有一个处理步骤
- 持续输入（`is_action_pressed`）在物理帧之间不更新——但对于射击（8 发/秒 = 125ms 间隔）来说 16.7ms 精度足够

### Risks
- **输入丢失**：如果物理帧耗时过长（>16.7ms），`is_action_just_pressed` 可能跳帧。缓解：60Hz 物理有充足余量（目标 ≤4.17ms，物理预算 ~2ms）
- **缓冲与去抖竞争**：去抖先执行，然后缓冲。确保缓冲不会绕过不去抖。已通过"去抖→缓冲→执行"顺序解决

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| input-system.md | 闪避去抖 50ms + 缓冲 100ms | `_input()` 标记 + `_physics_process()` 判定 |
| input-system.md | 双通道闪避（Shift+右键）同时按下只触发一次 | Input Map 统一 `dodge` 动作 + 去抖 |
| skill-system.md | AC7: 同帧释放+闪避 → 取消优先 | 显式处理顺序：dodge → skill_1 |
| dodge-system.md | 闪避期间移动/射击锁定，技能 1 不锁定 | `_physics_process` 中按状态屏蔽对应输入 |
| shooting-system.md | 闪避结束自动恢复射击 | 闪避结束后检查 `is_action_pressed("shoot")` |

## Performance Implications
- **CPU**: `Input.is_action_pressed()` 是哈希查找 → O(1)。每帧 ~6 次调用 ≈ 忽略不计
- **Memory**: 4 个标记变量（bool）+ 时间戳（int）≈ 20 字节
- **Load Time**: 无影响

## Validation Criteria
- Shift + 右键在 50ms 内先后按下 → 只触发 1 次闪避
- 技能 1 + 闪避同帧 → 技能取消，退还 75% CD
- 闪避结束且射击键仍按住 → 射击自动恢复
- 闪避期间按住 WASD → 无移动；闪避结束 → 移动立即恢复
