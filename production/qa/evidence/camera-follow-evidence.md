# Camera Follow Evidence -- Story 001

> **Epic**: camera-system
> **Story**: Story 001 - Follow + Aim Offset + Zoom
> **Type**: Visual/Feel (Advisory Gate)
> **Status**: Pending sign-off
> **Date**: [TO BE FILLED]

## QA Checklist

| # | Test | Expected Result | Pass? | Notes |
|---|------|----------------|-------|-------|
| 1 | Player moves right at full speed | Camera smoothly follows with slight delay (lerp 0.15), no snapping | [ ] | |
| 2 | Player moves left at full speed | Camera smoothly follows with slight delay, no snapping | [ ] | |
| 3 | Player moves up/down | Camera follows vertically with same lerp feel | [ ] | |
| 4 | Mouse cursor far right of player | Camera offsets ~80px right (player visible in left 40-50% of screen) | [ ] | |
| 5 | Mouse cursor far left of player | Camera offsets ~80px left (player visible in right 40-50% of screen) | [ ] | |
| 6 | Mouse cursor above player | Camera offsets upward | [ ] | |
| 7 | Mouse cursor below player | Camera offsets downward | [ ] | |
| 8 | Player near left scene boundary, mouse far right | Camera offset is reduced to keep camera within bounds | [ ] | |
| 9 | Player near right scene boundary, mouse far left | Camera offset is reduced to keep camera within bounds | [ ] | |
| 10 | Scroll wheel up (zoom out) | Camera zooms out smoothly (0.2s ease-in-out), larger visible area | [ ] | |
| 11 | Scroll wheel down (zoom in) | Camera zooms in smoothly (0.2s ease-in-out), smaller visible area | [ ] | |
| 12 | Zoom reaches zoom_min (1.0) | Cannot zoom in further, scroll has no effect beyond min | [ ] | |
| 13 | Zoom reaches zoom_max (3.0) | Cannot zoom out further, scroll has no effect beyond max | [ ] | |
| 14 | Rapid scroll wheel spinning | Zoom changes smoothly without jitter or snapping | [ ] | |
| 15 | Camera at scene boundary | Camera does not show area outside bounds (no black borders) | [ ] | |
| 16 | Aim offset combined with zoom | Offset scales appropriately with zoom level | [ ] | |

## Screenshots / Video

### Follow (no offset)
- [ ] Screenshot: Player centered, no mouse offset
  - Path: `production/qa/evidence/screenshots/camera-follow-centered.png`

### Aim Offset
- [ ] Screenshot: Mouse at far right, player on left side of screen
  - Path: `production/qa/evidence/screenshots/camera-follow-offset-right.png`
- [ ] Screenshot: Mouse at far left, player on right side of screen
  - Path: `production/qa/evidence/screenshots/camera-follow-offset-left.png`

### Zoom Levels
- [ ] Screenshot: Camera at zoom = 1.0 (closest)
  - Path: `production/qa/evidence/screenshots/camera-zoom-1.0.png`
- [ ] Screenshot: Camera at zoom = 2.0 (default)
  - Path: `production/qa/evidence/screenshots/camera-zoom-2.0.png`
- [ ] Screenshot: Camera at zoom = 3.0 (farthest)
  - Path: `production/qa/evidence/screenshots/camera-zoom-3.0.png`

### Boundary Clamping
- [ ] Screenshot: Player at left edge, no off-screen area visible
  - Path: `production/qa/evidence/screenshots/camera-boundary-left.png`

## Performance

| Metric | Value | Threshold | Pass? |
|--------|-------|-----------|-------|
| Frame time at 240fps (avg) | [ ] ms | < 4.17 ms | [ ] |
| Camera _process overhead | [ ] ms | < 0.05 ms | [ ] |
| Zoom tween overhead | [ ] ms | < 0.02 ms | [ ] |

## Edge Cases Observed

- [ ] No crash when follow_target is null (tested by temporarily removing player reference)
- [ ] No crash when InputSystem reference is null (fallback to get_global_mouse_position)
- [ ] No crash when scene limits are not configured (limit_left == limit_right == 0)
- [ ] Camera behaves correctly at all supported resolutions (960x540, 1920x1080)

## Known Issue(s)

- [None yet -- fill after testing]

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Implementer (engine-programmer) | | | |
| Lead (technical-director) | | | |
| QA (if applicable) | | | |
