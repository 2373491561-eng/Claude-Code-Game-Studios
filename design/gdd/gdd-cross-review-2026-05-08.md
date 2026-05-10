# Cross-GDD Review Report
Date: 2026-05-08
GDDs Reviewed: 20
Systems Covered: 18 system GDDs + game-concept + systems-index

## Verdict: CONCERNS

0 BLOCKER. 16 WARNING. All 24 cross-system values are consistent across all GDDs. No rule contradictions. No formula incompatibilities. All issues are documentation maintenance and ownership-level — do not block implementation.

## Consistency Issues (11 WARNING)

| # | Type | Finding |
|---|------|---------|
| 1 | ASYMMETRY | input-system lists menu-system as downstream; menu-system doesn't reference input |
| 2 | ASYMMETRY | scene-management lists wave-management as downstream; wave-management doesn't reference scene-management in Dependencies |
| 3 | ASYMMETRY | camera-system references shooting-system; shooting doesn't reference camera |
| 4 | ASYMMETRY | damage-health lists VFX as downstream; VFX doesn't list damage-health as event source |
| 5 | ASYMMETRY | meta-progression lists wave-management as upstream; wave-management doesn't reference meta-progression |
| 6 | STALE | camera-system.md: "所有依赖目前均无 GDD" — now false, all 4 upstream GDDs are Approved |
| 7 | STALE | systems-index.md Progress Tracker: counts show 0 reviewed/0 approved — actual is 18/20 Approved |
| 8 | OWNERSHIP | Perfect dodge distance (40px) defined in both dodge-system and damage-health. Owner: dodge-system |
| 9 | OWNERSHIP | skill_2 window (500ms) defined in both input-system and skill-system. Owner: skill-system |
| 10 | OWNERSHIP | Time scale duration (200ms) defined in both dodge-system and vfx-particles. Owner: dodge-system |
| 11 | OWNERSHIP | Death freeze (500ms) defined in both scene-management and damage-health. Owner: damage-health |

## Design Theory Issues (3 WARNING)

| # | Finding |
|---|---------|
| 12 | Peak combat: 7 concurrent attention channels. Diegetic UI mitigates. 3x3px dodge light dots at peripheral vision during 800-particle skill bursts — readability unverified |
| 13 | Firepower build direction has numerical advantage as "always-on" DPS. Playtest must track pick rates — if >50% always pick firepower, rebalance or add skill/dodge synergies |
| 14 | Wave 5-8 steepest difficulty gradient (+56% enemy HP vs +37-50% player power). Monitor completion rate cliff. Consider introducing large at wave 6 instead of wave 5 |

## Scenario Walkthrough Issues (2 WARNING)

| # | Finding |
|---|---------|
| 15 | VFX particle behavior during time_scale undefined — Tween.set_ignore_time_scale should be applied to particles during skill burst |
| 16 | Meta-progression depends on save-system (Polish layer, not MVP). MVP build has no persistence — unlocks last only for current session |

## Design Strengths Confirmed

- All 24 shared values (HP, damage, distances, timings, cooldowns) are consistent across all GDDs
- 5 formula chains (damage pipeline, dodge→CD, charge→acceleration, wave→spawn, shield timing) all compatible end-to-end
- All 4 anti-pillars clean — no system violates any anti-pillar
- All 4 pillars have primary and secondary system carriers
- Player fantasy across all 14 gameplay systems is mutually reinforcing
- Safety valves (charge=0 gate, CD 60% cap, cancel refund exemption) prevent degenerate strategies
- 3 progression loops (wave survival, roguelike build, meta-progression) are complementary, not competitive
