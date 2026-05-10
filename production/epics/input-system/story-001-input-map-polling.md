# Story 001: Input Map 搭建与核心轮询

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
**ADR Decision Summary**: 所有游戏输入动作统一在 `_physics_process()` 中通过 `Input.is_action_just_pressed()` / `Input.is_action_pressed()` 检测。`_input()` 仅用于去抖和缓冲的轻量状态标记。同帧优先级：dodge → skill_1 → shoot。

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `Input.is_action_just_pressed()` 在 Godot 4.x 中行为稳定，均在 LLM 训练数据内。

**Control Manifest Rules (Foundation)**:
- Required: 所有游戏输入动作在 `_physics_process()` 中执行；所有输入通过 Godot Input Map 动作引用
- Forbidden: 不要在 `_input()` 中执行游戏动作；不要硬编码按键检测

---

## Acceptance Criteria

- [ ] **AC1**: 7 个 Input Map 动作已注册：`move`, `aim`, `shoot`, `dodge`, `skill_1`, `pause`（`skill_2` 为自动触发，不占输入通道）
- [ ] **AC2**: `move` 动作绑定 WASD，轴值输出 Vector2(x, y)，范围 (-1..1, -1..1)
- [ ] **AC3**: `shoot` 动作绑定鼠标左键，`dodge` 动作绑定 Shift + 鼠标右键（双通道），`skill_1` 动作绑定空格，`pause` 动作绑定 Esc
- [ ] **AC4**: `_physics_process()` 中通过 `Input.is_action_just_pressed()` / `Input.is_action_pressed()` 轮询所有动作
- [ ] **AC5**: InputSystem 暴露公共接口：`get_move_axis(): Vector2`, `get_aim_direction(): Vector2`, `is_shoot_pressed(): bool`, `is_dodge_just_pressed(): bool`, `is_skill1_just_pressed(): bool`, `is_pause_just_pressed(): bool`
- [ ] **AC6**: `get_aim_direction()` 返回鼠标世界坐标 − 玩家位置的方向向量（归一化）

---

## Implementation Notes

1. **Input Map 注册**：在 Project Settings → Input Map 中创建 6 个动作（skill_2 不注册——它是自动触发的）。
   ```
   move: W(up) S(down) A(left) D(right)
   aim: 鼠标位置（通过 get_viewport().get_mouse_position() 获取）
   shoot: Mouse Button Left
   dodge: Key Shift + Mouse Button Right
   skill_1: Key Space
   pause: Key Escape
   ```
2. **轮询位置**：所有 `Input.is_action_*()` 调用放在 `_physics_process()` 中。不在 `_process()` 中轮询。
3. **`_input()` 不执行动作**：InputSystem 的 `_input(event)` 仅用于接收 debounce 时间戳标记（Story 002 实现）。当前 Story 可以先留空 `_input()`。
4. **`get_aim_direction()`**：`(get_viewport().get_mouse_position() - player_pos).normalized()`。注意零向量保护——鼠标恰好在玩家中心时返回 `Vector2.ZERO`。
5. **`get_move_axis()`**：直接返回 `Input.get_vector("move_left", "move_right", "move_up", "move_down")` 或手动组合 WASD 轴值。

---

## Out of Scope

- Story 002: 双通道闪避去抖（50ms）和输入缓冲（100ms）
- Story 003: 输入状态机（正常/闪避/技能/暂停/死亡状态切换）
- Story 004: 暂停菜单和失焦（Alt+Tab）处理
- 任何具体的移动/射击/闪避/技能执行逻辑（属于 Core 层）

---

## QA Test Cases

- **AC2**: WASD 输入轴值
  - Given: InputSystem 已初始化
  - When: 按住 W 键
  - Then: `get_move_axis()` 返回 Vector2(0, -1)（±0.1 容差）
  - Edge cases: W+D 同时按 → Vector2(0.707, -0.707)

- **AC5**: 公共接口完整性
  - Given: InputSystem 实例
  - When: 调用全部 6 个公共方法
  - Then: 每个方法返回声明的类型（Vector2 或 bool），不崩溃

- **AC3**: Input Map 动作存在性
  - Given: 项目 Input Map
  - When: 调用 `InputMap.has_action("dodge")`
  - Then: 返回 true（Shift 和右键均触发 `dodge` 动作）

- **AC6**: 瞄准方向计算
  - Given: 玩家位于 (500, 300)，鼠标位于 (600, 300)
  - When: 调用 `get_aim_direction()`
  - Then: 返回 Vector2(1, 0)（±0.01 容差）

- **AC6 边界**: 鼠标在玩家中心
  - Given: 玩家位于 (500, 300)，鼠标位于 (500, 300)
  - When: 调用 `get_aim_direction()`
  - Then: 返回 Vector2.ZERO（不崩溃，不返回 NaN）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input/input_polling_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (dodge debounce/buffer), Story 003 (input state machine)
