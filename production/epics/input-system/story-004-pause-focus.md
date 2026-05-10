# Story 004: 暂停与失焦处理

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Input Processing Architecture
**ADR Decision Summary**: `pause` 动作是最高优先级——任何状态下 Esc 立即暂停。暂停状态下仅 `pause` 动作有效（恢复）。失焦（Alt+Tab）自动暂停。

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `DisplayServer.window_get_focus()` 或 `NOTIFICATION_WM_WINDOW_FOCUS_OUT` 检测失焦——均在训练数据内。

**Control Manifest Rules (Foundation)**:
- Required: 暂停/恢复通过 EventBus 信号 `game_paused` / `game_resumed` 通知全系统
- Forbidden: 不要在暂停期间响应任何游戏输入（仅 Esc 有效）

---

## Acceptance Criteria

- [ ] **AC1**: Esc 按下 → 游戏立即暂停（`get_tree().paused = true`），通过 `EventBus.game_paused.emit()` 通知所有系统
- [ ] **AC2**: 暂停状态下再次按 Esc → 游戏恢复（`get_tree().paused = false`），通过 `EventBus.game_resumed.emit()` 通知
- [ ] **AC3**: 暂停状态下所有游戏输入被屏蔽——WASD/鼠标/Shift/Space 均无响应
- [ ] **AC4**: 暂停时 `_physics_process()` 停止执行（`get_tree().paused = true` 的效果），但 `_process()` 仍运行——暂停菜单动画需要 `_process()`
- [ ] **AC5**: Alt+Tab 切出窗口 → 自动暂停（触发 `game_paused`）
- [ ] **AC6**: Alt+Tab 切回窗口 → 保持暂停状态，不自动恢复（玩家需手动按 Esc 恢复）

---

## Implementation Notes

1. **暂停触发**：
   ```gdscript
   func _process_pause() -> void:
       if Input.is_action_just_pressed("pause"):
           if _state == InputState.PAUSED:
               _state = _previous_state  # 恢复到暂停前的状态
               get_tree().paused = false
               EventBus.game_resumed.emit()
           else:
               _previous_state = _state
               _state = InputState.PAUSED
               get_tree().paused = true
               EventBus.game_paused.emit()
   ```
   注意：`_process_pause()` 必须在 `_physics_process()` 中调用——`get_tree().paused = true` 会停止后续 `_physics_process()` 帧。所以暂停放在处理链的**最前面**。

2. **失焦检测**：
   ```gdscript
   func _notification(what: int) -> void:
       if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
           if _state != InputState.PAUSED and _state != InputState.DEAD:
               _previous_state = _state
               _state = InputState.PAUSED
               get_tree().paused = true
               EventBus.game_paused.emit()
   ```
   切回时**不自动恢复**——`get_tree().paused` 保持 true，玩家必须按 Esc。

3. **暂停期间 `_process()` 动画**：暂停菜单 UI（不在本 epic 范围）可以通过 `Node.process_mode = PROCESS_MODE_ALWAYS` 在暂停期间继续运行。

4. **优先级**：暂停检测在所有其他输入处理**之前**——如果 `is_action_just_pressed("pause")` 为 true，直接处理暂停/恢复，跳过所有其他输入。

---

## Out of Scope

- 暂停菜单 UI 设计和实现（属于 menu-system epic / Presentation 层）
- Story 001: Input Map 中 `pause` 动作注册
- Story 003: 输入状态机（PAUSED 状态的具体输入屏蔽规则）

---

## QA Test Cases

- **AC1**: Esc 暂停
  - Given: 状态 = NORMAL，`get_tree().paused = false`
  - When: 按 Esc（`Input.is_action_just_pressed("pause")` = true）
  - Then: `get_tree().paused = true`，`_state = PAUSED`，`EventBus.game_paused` 信号已发射

- **AC2**: Esc 恢复
  - Given: 状态 = PAUSED，`get_tree().paused = true`
  - When: 按 Esc
  - Then: `get_tree().paused = false`，`_state = _previous_state`（恢复到暂停前的状态），`EventBus.game_resumed` 已发射

- **AC3**: 暂停期间输入屏蔽
  - Given: 状态 = PAUSED
  - When: 按 WASD / 鼠标左键 / Shift / 空格
  - Then: `get_move_axis()` → Vector2.ZERO；`is_shoot_pressed()` / `is_dodge_just_pressed()` / `is_skill1_just_pressed()` → 全部 false
  - Edge cases: 暂停期间按住 WASD → 恢复后 WASD 立即响应（状态恢复）

- **AC5**: 失焦自动暂停
  - Given: 状态 = NORMAL（游戏中）
  - When: 收到 `NOTIFICATION_WM_WINDOW_FOCUS_OUT`
  - Then: `get_tree().paused = true`，`_state = PAUSED`，`_previous_state = NORMAL`

- **AC6**: 切回保持暂停
  - Given: 失焦已触发暂停（`get_tree().paused = true`）
  - When: 窗口重新获得焦点
  - Then: `get_tree().paused` 仍为 true，状态仍为 PAUSED（不自动恢复）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input/pause_focus_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Input Map + core polling — `pause` 动作必须已注册), Story 003 (input state machine — PAUSED 状态)
- Unlocks: None (leaf story)
