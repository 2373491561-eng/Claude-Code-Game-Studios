# Story 002: 双通道闪避去抖与缓冲

> **Epic**: input-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/input-system.md`
**Requirement**: `TR-input-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Input Processing Architecture, ADR-0001: Real-Time Timing Strategy
**ADR Decision Summary**: 闪避双通道（Shift + 右键）通过 Input Map 统一 `dodge` 动作。`_input()` 中标记按下时间戳和队列标志（轻量），`_physics_process()` 中执行去抖（50ms）→ 缓冲（100ms）→ 动作执行。所有计时使用 `Time.get_ticks_msec()`（不受 `Engine.time_scale` 影响）。

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `Time.get_ticks_msec()` 返回 OS 单调时钟，不受 `Engine.time_scale` 影响——已确认。

**Control Manifest Rules (Foundation)**:
- Required: `_input()` 仅做标记（时间戳+标志），`_physics_process()` 执行动作；所有计时使用 `Time.get_ticks_msec()`
- Forbidden: 不要在 `_input()` 中触发闪避执行；不要使用 `delta` 累加计时

---

## Acceptance Criteria

- [ ] **AC1**: Shift 和鼠标右键均映射至同一 `dodge` 动作（通过 Godot Input Map），任一按下触发 `_dodge_queued = true`
- [ ] **AC2**: 去抖窗口 50ms——两键在 50ms 内先后按下只标记 1 次 `_dodge_queued`
- [ ] **AC3**: 去抖使用 `Time.get_ticks_msec()` 比较时间戳——不受 `Engine.time_scale` 影响
- [ ] **AC4**: 输入缓冲 100ms——当前闪避结束前 100ms 内按下闪避键 → `_dodge_buffered = true`，结束后自动触发下一次
- [ ] **AC5**: `_physics_process()` 中处理顺序：先去抖判定 → 再缓冲判定 → 最后执行闪避（调用 `dodge_system.execute_dodge()`）
- [ ] **AC6**: 去抖和缓冲不互相干扰——去抖先执行，缓冲使用去抖后的结果

---

## Implementation Notes

1. **`_input(event)` 轻量标记**：
   ```gdscript
   func _input(event: InputEvent) -> void:
       if event.is_action_pressed("dodge"):
           _dodge_raw_time_ms = Time.get_ticks_msec()
           _dodge_queued = true
   ```
   不要在这里执行闪避。不要在这里做任何耗时操作。

2. **`_physics_process()` 三步处理**：
   ```gdscript
   func _process_dodge() -> void:
       if not _dodge_queued: return
       var now = Time.get_ticks_msec()
       # Step 1: 去抖
       if now - _last_dodge_ms < DEBOUNCE_MS:  # 50ms
           _dodge_queued = false
           return
       # Step 2: 缓冲
       if not dodge_system.can_dodge():
           if dodge_system.dodge_ending_soon():  # 100ms
               _dodge_buffered = true
           _dodge_queued = false
           return
       # Step 3: 执行
       dodge_system.execute_dodge()
       _last_dodge_ms = now
       _dodge_queued = false
   ```

3. **缓冲兑现**：在 `_physics_process()` 开始处检查 `_dodge_buffered && dodge_system.can_dodge()`，如果可以 → 执行缓冲的闪避并清除 `_dodge_buffered`。

4. **常量定义**：
   ```gdscript
   const DEBOUNCE_MS = 50
   const BUFFER_MS = 100
   ```

---

## Out of Scope

- Story 001: Input Map 基础搭建（`dodge` 动作注册）
- Story 003: 输入状态机（闪避期间屏蔽移动/射击，闪避结束恢复）
- 闪避系统具体逻辑（位移、无敌帧、充能）——属于 dodge-system epic

---

## QA Test Cases

- **AC1**: 双通道映射
  - Given: Input Map 已注册 `dodge` 动作（Shift + 右键）
  - When: 按 Shift → 释放 → 按右键
  - Then: 两次均设置 `_dodge_queued = true`

- **AC2**: 去抖窗口
  - Given: `_last_dodge_ms = 0`，当前时间 T
  - When: 按 Shift（T），30ms 后按右键（T+30ms）
  - Then: `_dodge_queued` 仅在第一次按下时为 true，第二次被去抖吞掉
  - Edge cases: 间隔 51ms → 两次均通过去抖

- **AC3**: 真实时间去抖——time_scale 不影响
  - Given: `Engine.time_scale = 0.2`
  - When: 按 Shift，150ms 真实时间后按右键
  - Then: 150ms > 50ms 去抖窗口 → 两次均通过（time_scale 不延长去抖窗口）

- **AC4**: 输入缓冲
  - Given: 闪避进行中（剩余 50ms），充能可用
  - When: 按 Shift（`_dodge_buffered = true`）
  - Then: 当前闪避结束后 1 帧内自动触发下一次闪避
  - Edge cases: 闪避剩余 101ms 时按下 → 不缓冲（超出 100ms 窗口）

- **AC6**: 去抖与缓冲顺序
  - Given: 闪避剩余 50ms（在缓冲窗口内），玩家连按 Shift 两次（间隔 20ms）
  - When: 处理输入
  - Then: 去抖将两次合并为 1 次，缓冲判定使用合并后的结果。闪避结束后触发 1 次缓冲闪避（非 2 次）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/input/dodge_debounce_buffer_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Input Map + core polling — `dodge` 动作必须已注册)
- Unlocks: Story 003 (input state machine depends on debounce/buffer being functional)
