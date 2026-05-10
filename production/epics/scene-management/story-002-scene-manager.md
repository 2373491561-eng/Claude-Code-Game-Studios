# Story 002: SceneManager 场景切换

> **Epic**: scene-management
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/scene-management.md`
**Requirement**: `TR-scene-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Scene Lifecycle & Autoload Design
**ADR Decision Summary**: 3 场景流（main_menu → game → death_screen → main_menu）。使用 `SceneTree.change_scene_to_file()` 切换。战斗场景每次新 Run 完全重新加载（零状态残留）。场景切换带淡入淡出过渡 + 500ms 去抖。

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `change_scene_to_file()` 为同步加载——960×540 像素场景预期 <100ms。

**Control Manifest Rules (Foundation)**:
- Required: 使用 `change_scene_to_file()` 切换场景；新 Run = 完全重新加载 `game.tscn`
- Forbidden: 不要手动重置节点状态（用重新加载替代）

---

## Acceptance Criteria

- [ ] 3 个场景文件存在：`main_menu.tscn`, `game.tscn`, `death_screen.tscn`（即使只有根节点）
- [ ] `SceneManager.switch_to(scene_id: String, data: Dictionary)` 方法实现
- [ ] 场景切换使用 `ResourceLoader.load()` + `get_tree().change_scene_to_packed()` 或 `change_scene_to_file()`
- [ ] 场景切换过渡动画：淡出 150ms → 加载 → 淡入 150ms（ColorRect 全屏 overlay）
- [ ] 场景切换去抖：500ms 内多次调用 `switch_to()` 只执行第一次
- [ ] `get_current_scene(): String` 返回当前场景 ID
- [ ] 战斗场景加载时调用 `GameManager.start_new_run()`
- [ ] 死亡场景加载时携带本局统计数据（从 `GameManager.current_run` 读取）
- [ ] 场景文件缺失时显示错误提示并回到主菜单（不卡黑屏）

---

## Implementation Notes

1. **场景枚举与路径映射**：
   ```gdscript
   enum SceneID { MAIN_MENU, GAME, DEATH_SCREEN }
   const SCENE_PATHS = {
       SceneID.MAIN_MENU: "res://src/scenes/main_menu.tscn",
       SceneID.GAME: "res://src/scenes/game.tscn",
       SceneID.DEATH_SCREEN: "res://src/scenes/death_screen.tscn",
   }
   ```

2. **过渡 overlay**：CanvasLayer + ColorRect（纯黑），tween 透明度实现淡入淡出。

3. **去抖**：
   ```gdscript
   const SWITCH_DEBOUNCE_MS = 500
   var _last_switch_ms: int = 0
   func switch_to(scene_id: String, data: Dictionary = {}) -> void:
       var now = Time.get_ticks_msec()
       if now - _last_switch_ms < SWITCH_DEBOUNCE_MS: return
       _last_switch_ms = now
       _do_switch(scene_id, data)
   ```

---

## QA Test Cases

- **Flow**: 主菜单 → "开始" → 战斗场景 → 死亡 → 结算 → "返回" → 主菜单 — 完整循环无报错
- **去抖**: 500ms 内连续调用 `switch_to()` 3 次 → 只切换 1 次
- **重置**: 新 Run 的 `game.tscn` 中无上一局的残留敌人/粒子
- **容错**: 场景文件路径无效 → 显示错误提示（`push_error()`），回到主菜单

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scene/scene_switch_test.gd` OR manual playtest doc

## Dependencies

- Depends on: Story 001 (GameManager Autoload)
- Unlocks: Story 003 (AudioManager BGM continuity depends on scene switching events)
