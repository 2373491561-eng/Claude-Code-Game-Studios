# Story 001: 摄像机跟随 + 瞄准偏移 + 缩放

> **Epic**: camera-system
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-05-10

## Context

**GDD**: `design/gdd/camera-system.md`
**Requirement**: `TR-cam-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Camera Shake System
**ADR Decision Summary**: Camera2D 平滑跟随玩家（lerp），瞄准方向偏移 10-15%（~80px），鼠标滚轮缩放（1.5m-4m 等效视野）。所有过渡使用 `Tween`。

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `Camera2D` 节点，`position` 平滑跟随，`zoom` 属性控制缩放。均在训练数据内。

**Control Manifest Rules (Presentation)**:
- Required: 跟随使用 lerp；偏移使用 ease-out；缩放 0.2s 过渡
- Forbidden: 不要让摄像机超出场景边界

---

## Acceptance Criteria

- [ ] Camera2D 平滑跟随玩家（lerp speed = 0.15），玩家始终在画面 40-50% 位置
- [ ] 瞄准偏移：向 `aim_direction` 偏移 max 80px，ease-out 缓动
- [ ] 鼠标滚轮向上 → 缩小视野（zoom 增大，最远 3.0）
- [ ] 鼠标滚轮向下 → 放大视野（zoom 减小，最近 1.0）
- [ ] 缩放过渡 0.2s ease-in-out
- [ ] 摄像机 clamp 到场景边界内
- [ ] 偏移接近边界时自动缩减偏移量

---

## QA Test Cases

- 跟随：玩家移动 → 摄像机在 0.5s 内跟上（可见延迟但无跳变）
- 偏移：鼠标在角色右侧 → 摄像机 x 偏移 > 0；鼠标在左侧 → 偏移 < 0
- 缩放：滚轮向上 3 格 → zoom 从 2.0 递减至 ~1.4（可配置）

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/camera-follow-evidence.md` + sign-off

## Dependencies

- Depends on: PlayerMovement（玩家坐标）, InputSystem（aim 方向）
- Unlocks: Story 002 (camera shake)
