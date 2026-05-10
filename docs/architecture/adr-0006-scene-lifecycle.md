# ADR-0006: Scene Lifecycle & Autoload Design

## Status
Accepted

## Date
2026-05-08

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `SceneTree.change_scene_to_file()` synchronous load time for 960×540 scenes |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005 (event architecture — EventBus is an Autoload) |
| **Enables** | Save system (future), Meta-progression (future) |
| **Blocks** | SceneManager implementation |
| **Ordering Note** | GameManager and AudioManager must be created as Autoloads before game.tscn |

## Context

### Problem Statement
游戏有 3 个场景（主菜单、战斗、死亡结算）。Run 状态（波次、构筑、击杀数）需要在场景切换间保持。背景音乐需要无缝过渡。Godot 的默认行为是场景切换时释放当前场景的所有节点——如果没有跨场景单例，Run 状态和音频连续性会丢失。

场景管理 GDD 定义了 3 场景流和 2 个 Autoload（GameManager、AudioManager）。此 ADR 定义它们的数据所有权和生命周期。

### Constraints
- Godot 4.6.2 `SceneTree.change_scene_to_file()` 用于场景切换
- Autoload 在引擎启动时加载，在所有场景之前存在
- 战斗场景是唯一承载全部玩法的场景
- Roguelike Run 本身不持久化（死亡 = 状态丢失，只有跨局进度保留）

### Requirements
- Run 状态跨场景保持
- BGM 跨场景无缝过渡
- 战斗场景每次新 Run 完全重置

## Decision

**两个 Autoload 单例管理跨场景状态：GameManager（Run 数据）+ AudioManager（音频连续性）。场景切换通过 `change_scene_to_file()` 执行，过渡使用淡入淡出。战斗场景每次新 Run 重新加载以清空所有状态。**

### GameManager

```gdscript
# Autoload — 在 project.godot 中注册
class_name GameManager extends Node

var current_run: RunState  # null = 不在 Run 中

class RunState:
    var wave: int = 0
    var kills: int = 0
    var build_choices: Array[String] = []  # 构筑选择记录
    var perfect_dodges: int = 0
    var total_damage_dealt: int = 0
    var start_time_ms: int = 0
    var end_time_ms: int = 0

func start_new_run() -> void:
    current_run = RunState.new()
    current_run.start_time_ms = Time.get_ticks_msec()

func end_run() -> void:
    current_run.end_time_ms = Time.get_ticks_msec()
    # 跨局进度更新（待跨局进度系统实现）

func get_run_duration_seconds() -> float:
    return (current_run.end_time_ms - current_run.start_time_ms) / 1000.0
```

### AudioManager

```gdscript
# Autoload — 在 project.godot 中注册
class_name AudioManager extends Node

var _current_bgm: BGMState = BGMState.NONE

enum BGMState { NONE, MENU, COMBAT, DEATH }

func crossfade_bgm(target: BGMState, duration: float = 0.5) -> void:
    if _current_bgm == target:
        return
    # 淡出当前 BGM + 淡入目标 BGM
    # ... Tween 实现
    _current_bgm = target
```

### Scene Flow

```
main_menu.tscn          game.tscn           death_screen.tscn
     │                      │                      │
     │  start_new_run()     │                      │
     ├──────────────────────►                      │
     │  change_scene()      │                      │
     │                      │  end_run()           │
     │                      ├──────────────────────►
     │                      │  change_scene()      │
     │  change_scene()      │                      │
     │◄─────────────────────┼──────────────────────┤
     │  (返回主菜单)         │                      │
```

## Alternatives Considered

### Alternative 1: 战斗场景重置（不重新加载）
- **Pros**: 更快（无文件 I/O），保持在当前场景
- **Cons**: 必须手动重置所有节点状态——容易遗漏（残留粒子、上一个 Run 的敌人引用、UI 状态）。不如重新加载干净
- **Rejection Reason**: 场景管理 GDD 开放问题讨论了两者——选择重新加载以确保零残留

### Alternative 2: GameManager 作为场景内节点而非 Autoload
- **Pros**: 不引入全局状态
- **Cons**: 场景切换时会销毁——Run 状态丢失
- **Rejection Reason**: 核心需求是跨场景保持 Run 状态

## Consequences

### Positive
- 场景切换 = 完整的沙盒重置——无残留状态
- GameManager 是所有 Run 数据的唯一真实来源
- AudioManager 保证 BGM 无缝过渡
- 新场景（如设置画面）可以随时添加到流中

### Negative
- 重新加载 `game.tscn` 有 I/O 开销（960×540 像素场景预期 <100ms——可接受）
- 两个 Autoload 是全局可变状态——测试时需要 mock
- `RunState` 结构随着 Feature 层系统添加会持续膨胀

### Risks
- **GameManager 数据膨胀**：跨局进度、成就等加入后 RunState 过大。缓解：GameManager 只保存当前 Run 数据。跨局数据在独立系统中
- **场景切换竞态**：快速返回→开始可能导致过渡重叠。缓解：场景管理 GDD 规定 500ms 去抖窗口

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| scene-management.md | 3 场景流：菜单→战斗→死亡→菜单 | `change_scene_to_file()` 实现 |
| scene-management.md | GameManager + AudioManager Autoload | 双 Autoload 设计 |
| scene-management.md | 每局新 Run 完全清空上一局残留 | 重新加载 game.tscn |
| scene-management.md | BGM 跨场景不断 | AudioManager.crossfade_bgm() |

## Validation Criteria
- 菜单 → 战斗 → 死亡 → 菜单：完整循环无报错
- 上一局敌人在新 Run 中不存在
- 场景切换期间 BGM 无缝过渡
- 场景切换去抖：500ms 内连点只触发 1 次
