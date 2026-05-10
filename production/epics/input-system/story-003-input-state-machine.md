# Story 003: 输入状态机

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Input Processing Architecture
**ADR Decision Summary**: `_physics_process()` 中按固定优先级处理输入：dodge → skill_1 → shoot → move。同帧取消优先：闪避取消技能 1（退还 75% CD）。各状态下的输入屏蔽规则在输入层实现——闪避期间移动/射击锁定，技能 1 不锁定。

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: 无 post-cutoff API。`Input.is_action_pressed()` 和 `Input.is_action_just_pressed()` 均在训练数据内。

**Control Manifest Rules (Foundation)**:
- Required: 同帧优先级 dodge → skill_1 → shoot；闪避取消技能 1（启动阶段 0-200ms）
- Forbidden: 不要在 `_input()` 中切换输入状态

---

## Acceptance Criteria

- [ ] **AC1**: 5 个输入状态：NORMAL（全输入可用）、DODGING（仅 aim + skill_1）、SKILL_CASTING（aim + dodge 可取消）、PAUSED（仅 pause 恢复）、DEAD（无输入）
- [ ] **AC2**: `_physics_process()` 中处理顺序：`_process_dodge()` → `_process_skill()` → `_process_shoot()` → `_process_move()`
- [ ] **AC3**: 闪避期间（DODGING 状态）：移动输入被忽略（velocity = 0），射击不生成子弹，瞄准方向不变
- [ ] **AC4**: 闪避期间技能 1 仍可释放（空格键不被屏蔽）
- [ ] **AC5**: 技能释放期间（SKILL_CASTING 状态）：可全速移动，可闪避取消（同帧取消优先规则）
- [ ] **AC6**: 闪避结束后若射击键从未松开 → 自动恢复射击（状态切换回 NORMAL 时检查 `is_shoot_pressed()`）
- [ ] **AC7**: 死亡状态（DEAD）：所有游戏输入冻结，不响应任何按键

---

## Implementation Notes

1. **状态枚举**：
   ```gdscript
   enum InputState { NORMAL, DODGING, SKILL_CASTING, PAUSED, DEAD }
   var _state: InputState = InputState.NORMAL
   ```

2. **每状态允许的输入**：
   ```gdscript
   func _get_allowed_actions(state: InputState) -> Dictionary:
       match state:
           InputState.NORMAL:
               return {move=true, aim=true, shoot=true, dodge=true, skill_1=true, pause=true}
           InputState.DODGING:
               return {move=false, aim=true, shoot=false, dodge=false, skill_1=true, pause=true}
           InputState.SKILL_CASTING:
               return {move=true, aim=true, shoot=true, dodge=true, skill_1=false, pause=true}
           InputState.PAUSED:
               return {move=false, aim=false, shoot=false, dodge=false, skill_1=false, pause=true}
           InputState.DEAD:
               return {move=false, aim=false, shoot=false, dodge=false, skill_1=false, pause=false}
   ```

3. **状态切换由外部系统触发**：
   - `DodgeSystem` 进入闪避时 → 调用 `InputSystem.set_state(DODGING)`
   - `DodgeSystem` 闪避结束时 → 调用 `InputSystem.set_state(NORMAL)`
   - `SkillSystem` 释放开始时 → 调用 `InputSystem.set_state(SKILL_CASTING)`
   - `SkillSystem` 释放结束时 → 调用 `InputSystem.set_state(NORMAL)`
   - 暂停/死亡同理

4. **同帧取消优先**（在 `_process_skill()` 中）：
   ```gdscript
   if dodge_triggered and skill_1_triggered_on_same_frame:
       if skill_system.is_in_startup_phase():  # 0-200ms
           skill_system.cancel()
           # 退还 75% CD（由 SkillSystem 处理）
       # 否则两者均执行
   ```

5. **闪避结束自动恢复射击**：在 `set_state(NORMAL)` 时检查——如果 `is_shoot_pressed()` 为 true → 发射 `shoot_resumed` 信号。

---

## Out of Scope

- Story 001: Input Map 和 `is_action_*()` 底层轮询
- Story 002: 闪避去抖和缓冲逻辑
- Story 004: 暂停触发和失焦处理
- 闪避系统实际位移/无敌帧/充能逻辑（dodge-system epic）
- 技能系统冷却/释放逻辑（skill-system epic）

---

## QA Test Cases

- **AC2**: 处理优先级
  - Given: 同帧 dodge 和 skill_1 同时触发（均在 `_physics_process` 中）
  - When: 技能处于启动阶段（0-200ms）
  - Then: dodge 先处理 → 取消 skill_1 → skill_1 退还 75% CD → shoot 跳过（因为状态已是 DODGING）

- **AC3**: 闪避期间输入屏蔽
  - Given: 状态 = DODGING
  - When: 读取移动轴值、检查射击按下、检查闪避按下
  - Then: `get_move_axis()` → Vector2.ZERO；`is_shoot_pressed()` → false（屏蔽）；`is_dodge_just_pressed()` → false（屏蔽）；`is_skill1_just_pressed()` → 正常返回
  - Edge cases: 玩家在闪避期间按住 WASD → 闪避结束 → 移动立即恢复（`get_move_axis()` 返回正确值）

- **AC6**: 闪避结束自动恢复射击
  - Given: 闪避前 `is_shoot_pressed()` = true，闪避中状态 = DODGING
  - When: DodgeSystem 调用 `set_state(NORMAL)`
  - Then: 检测到 `is_shoot_pressed()` 仍为 true → 发射 `shoot_resumed` 信号或直接允许射击轮询
  - Edge cases: 闪避期间松开了射击键 → `set_state(NORMAL)` 时不恢复射击

- **AC7**: 死亡状态全锁定
  - Given: 状态 = DEAD
  - When: 按任意游戏按键（WASD/鼠标/空格/Shift）
  - Then: 所有 `get_*` / `is_*` 方法返回默认值（Vector2.ZERO / false），pause 也返回 false

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/input/input_state_machine_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Input Map + core polling), Story 002 (dodge debounce/buffer)
- Unlocks: None directly (parallel to Story 004)
