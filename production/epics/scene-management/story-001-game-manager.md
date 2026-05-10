# Story 001: GameManager Autoload + RunState

> **Epic**: scene-management
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/scene-management.md`
**Requirement**: `TR-scene-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Scene Lifecycle & Autoload Design
**ADR Decision Summary**: GameManager 作为 Autoload 管理 Run 状态——当前波次、击杀数、构筑选择、统计数据。新 Run 通过 `start_new_run()` 初始化，死亡通过 `end_run()` 记录统计。Run 数据不持久化（Roguelike 设计）。

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Autoload 在 `project.godot` 中注册，引擎启动时加载，在所有场景之前存在。

**Control Manifest Rules (Foundation)**:
- Required: Autoload 在 `project.godot` 中注册；`RunState` 数据结构包含所有跨场景保持的字段
- Forbidden: 不要在 GameManager 中保存 Run 中间状态到磁盘

---

## Acceptance Criteria

- [ ] GameManager 在 `project.godot` 中注册为 Autoload（`class_name GameManager extends Node`）
- [ ] `RunState` 内部类包含：`wave: int`, `kills: int`, `build_choices: Array[String]`, `perfect_dodges: int`, `total_damage_dealt: int`, `start_time_ms: int`, `end_time_ms: int`
- [ ] `start_new_run()` 初始化所有 Run 字段为默认值，记录 `start_time_ms = Time.get_ticks_msec()`
- [ ] `end_run()` 设置 `end_time_ms`，`get_run_duration_seconds()` 返回精确到 0.1s 的时长
- [ ] `current_run` 为 null 时表示不在 Run 中
- [ ] `record_kill()` 递增 `kills` 计数器

---

## Implementation Notes

```gdscript
# Autoload — project.godot:
# [autoload]
# GameManager="*res://src/autoloads/game_manager.gd"

class_name GameManager extends Node

var current_run: RunState = null

class RunState:
    var wave: int = 0
    var kills: int = 0
    var build_choices: Array[String] = []
    var perfect_dodges: int = 0
    var total_damage_dealt: int = 0
    var start_time_ms: int = 0
    var end_time_ms: int = 0

func start_new_run() -> void:
    current_run = RunState.new()
    current_run.start_time_ms = Time.get_ticks_msec()

func end_run() -> void:
    current_run.end_time_ms = Time.get_ticks_msec()

func get_run_duration_seconds() -> float:
    return round((current_run.end_time_ms - current_run.start_time_ms) / 100.0) / 10.0

func record_kill() -> void:
    if current_run:
        current_run.kills += 1
```

---

## QA Test Cases

- **AC1**: GameManager Autoload 存在性 — Given: 游戏启动 — When: 在任意场景中访问 `GameManager` — Then: `GameManager is GameManager` 为 true
- **AC3**: `start_new_run()` 初始化 — Given: `current_run == null` — When: `GameManager.start_new_run()` — Then: `current_run.wave == 0`, `current_run.kills == 0`, `current_run.start_time_ms > 0`
- **AC5**: `current_run` null 检查 — Given: 游戏刚启动未开始 Run — When: 读取 `GameManager.current_run` — Then: 为 null

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/scene/game_manager_test.gd`

## Dependencies

- Depends on: None
- Unlocks: Story 002 (SceneManager depends on GameManager)
