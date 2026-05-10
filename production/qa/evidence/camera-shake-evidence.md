# Camera Shake Evidence -- Story 002

> **Epic**: camera-system
> **Story**: Story 002 - 5-Level Camera Shake
> **Type**: Visual/Feel (Advisory Gate)
> **Status**: Pending sign-off
> **Date**: [TO BE FILLED]

## QA Checklist

| # | Test | Expected Result | Pass? | Notes |
|---|------|----------------|-------|-------|
| 1 | Trigger PLAYER_HIT shake (3px, 100ms) | Subtle jitter, barely perceptible, quick recovery | [ ] | |
| 2 | Trigger PERFECT_DODGE shake (5px, 150ms) | Noticeable shake, smooth ease-out decay | [ ] | |
| 3 | Trigger SKILL_BURST shake (12px, 300ms) | Strong shake, screen rattles, ease-out decay | [ ] | |
| 4 | Trigger LARGE_ENEMY_APPEAR shake (8px, 200ms) | Medium-strong shake, ease-in-out curve | [ ] | |
| 5 | Trigger DEATH shake (20px, 500ms) | Very strong shake, dramatic, ease-out decay | [ ] | |
| 6 | SHAKE: time_scale=0.2, trigger SKILL_BURST | Shake completes in 300ms real time (NOT 1.5s stretched) | [ ] | |
| 7 | SHAKE: time_scale=0.2, trigger DEATH | Shake completes in 500ms real time (NOT 2.5s stretched) | [ ] | |
| 8 | Trigger PLAYER_HIT + SKILL_BURST simultaneously | Only SKILL_BURST plays (12px > 3px, strongest wins) | [ ] | |
| 9 | Trigger SKILL_BURST, then PLAYER_HIT during shake | PLAYER_HIT is ignored (shake intensity 3 < 12) | [ ] | |
| 10 | Trigger DEATH, then SKILL_BURST during shake | SKILL_BURST is ignored (shake intensity 12 < 20) | [ ] | |
| 11 | Trigger PLAYER_HIT during PERFECT_DODGE shake | PLAYER_HIT is ignored (3 < 5) | [ ] | |
| 12 | Trigger PERFECT_DODGE during PLAYER_HIT shake | PERFECT_DODGE overrides PLAYER_HIT (5 > 3) | [ ] | |
| 13 | Shake completes normally | Camera offset returns to Vector2.ZERO after shake | [ ] | |
| 14 | Multiple shakes in sequence (not overlapping) | Each shake plays fully, offset resets between shakes | [ ] | |
| 15 | Shake direction is random each frame | Offsets are not always in the same direction | [ ] | |

## Screenshots / Video

### Individual Shake Types (video clips preferred)
- [ ] Video: PLAYER_HIT shake
  - Path: `production/qa/evidence/screenshots/camera-shake-player-hit.mp4`
- [ ] Video: PERFECT_DODGE shake
  - Path: `production/qa/evidence/screenshots/camera-shake-perfect-dodge.mp4`
- [ ] Video: SKILL_BURST shake
  - Path: `production/qa/evidence/screenshots/camera-shake-skill-burst.mp4`
- [ ] Video: LARGE_ENEMY_APPEAR shake
  - Path: `production/qa/evidence/screenshots/camera-shake-large-enemy.mp4`
- [ ] Video: DEATH shake
  - Path: `production/qa/evidence/screenshots/camera-shake-death.mp4`

### Strength Comparison
- [ ] Screenshot: Frame showing max offset during PLAYER_HIT vs SKILL_BURST vs DEATH
  - Path: `production/qa/evidence/screenshots/camera-shake-strength-comparison.png`

### Time-Scale Independence
- [ ] Video: SKILL_BURST at time_scale=0.2 (confirm 300ms real time)
  - Path: `production/qa/evidence/screenshots/camera-shake-timescale-0.2.mp4`

## Shake Configuration (Reference)

| ShakeType | Intensity (px) | Duration (ms) | Decay Curve |
|-----------|:--------------:|:-------------:|-------------|
| PLAYER_HIT | 3 | 100 | linear |
| PERFECT_DODGE | 5 | 150 | ease_out |
| SKILL_BURST | 12 | 300 | ease_out |
| LARGE_ENEMY_APPEAR | 8 | 200 | ease_in_out |
| DEATH | 20 | 500 | ease_out |

## Edge Cases Observed

- [ ] No crash when shake triggered before camera is in scene tree
- [ ] No crash when EventBus is absent (shake signals silently not connected)
- [ ] Shake does not accumulate — offset returns to Vector2.ZERO between shakes
- [ ] Very rapid repeated shakes of same type (PLAYER_HIT x5) do not cause visual artifacts
- [ ] Shake at extreme zoom levels still looks correct

## Known Issue(s)

- [None yet -- fill after testing]

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Implementer (engine-programmer) | | | |
| Lead (technical-director) | | | |
| QA (if applicable) | | | |
