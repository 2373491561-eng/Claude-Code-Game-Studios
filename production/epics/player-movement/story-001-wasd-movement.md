# Story 001: WASD 八方向移动

> **Epic**: player-movement
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/player-movement.md`
**Requirement**: `TR-move-001`
**ADR Governing Implementation**: ADR-0002: Input Processing Architecture
**ADR Decision Summary**: 读取 InputSystem `move` 轴值，300px/s 恒定速度，对角线归一化。使用 `CharacterBody2D.move_and_slide()` 处理碰撞。

**Engine**: Godot 4.6.2 | **Risk**: LOW

**Control Manifest Rules (Core)**:
- Required: `CharacterBody2D.move_and_slide()`；对角线归一化
- Forbidden: 不要在闪避期间响应移动输入

---

## Acceptance Criteria

- [ ] WASD 八方向移动，300px/s 恒定速度
- [ ] 对角线归一化——W+D 速度 = 300px/s，非 424px/s
- [ ] 即时启停，无惯性（velocity 直接赋值，不使用加速度）
- [ ] 反向瞬切无延迟（W → S 立即改变方向）
- [ ] `CharacterBody2D.move_and_slide()` 处理障碍物碰撞
- [ ] 闪避期间 velocity = Vector2.ZERO（输入屏蔽来自 InputSystem）
- [ ] 闪避结束立即恢复移动
- [ ] 移动与射击完全独立——`move_axis` 不影响 `aim_direction`

---

## Implementation Notes

```gdscript
class_name PlayerMovement extends CharacterBody2D

@export var move_speed: float = 300.0

func _physics_process(_delta: float) -> void:
    var move_axis = InputSystem.get_move_axis()
    if move_axis.length() > 1.0: move_axis = move_axis.normalized()
    if InputSystem.is_movement_locked(): move_axis = Vector2.ZERO
    velocity = move_axis * move_speed
    move_and_slide()
```

---

## QA Test Cases

- W 键: velocity = (0, -300) → 1 秒移动 300px 向上
- W+D: velocity ≈ (212, -212) → 对角线速度 300px/s（归一化）
- W→S 瞬切: 方向立即反转，无过渡帧
- 闪避中: WASD 无响应（velocity = 0）

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/movement/movement_test.gd`

## Dependencies

- Depends on: InputSystem (Story 001-004 of input-system epic)
- Unlocks: dodge-system, shooting-system
