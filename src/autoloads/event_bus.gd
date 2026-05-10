## EventBus -- global signal bus for cross-system event communication.
##
## This is an Autoload (registered in project.godot) that carries all
## cross-system signals per ADR-0005. Core systems emit signals here;
## Presentation systems connect to them. This decouples Core from
## Presentation -- Core never calls Presentation code directly.
##
## Usage:
##   [codeblock]
##   # Emitting (in a Core system):
##   EventBus.game_paused.emit()
##
##   # Connecting (in a Presentation system):
##   EventBus.game_paused.connect(_on_game_paused)
##   [/codeblock]
##
## Signal naming convention: snake_case past tense (e.g., game_paused).
##
## Full signal list is defined in ADR-0005. Only the game_paused and
## game_resumed signals are defined here initially; additional signals
## will be added as they are needed by implemented systems.
extends Node

## Emitted when the game is paused (Esc pressed or focus loss).
signal game_paused()

## Emitted when the game is resumed (Esc pressed while paused).
signal game_resumed()

## Emitted when a bullet hits an enemy.
##
## [param hit_pos] World-space position of the hit.
## [param is_skill2] True if skill_2 was active for this hit (double damage, pierce).
signal bullet_hit(hit_pos: Vector2, is_skill2: bool)

## Emitted when the player executes a normal dodge.
##
## [param pos] World-space position of the player at dodge start.
## [param direction] Normalized direction of the dodge displacement.
signal dodge_normal(pos: Vector2, direction: Vector2)

## Emitted when the player executes a perfect dodge.
##
## [param pos] World-space position of the player at dodge start.
## [param charge_count] Number of dodge charges at time of trigger.
signal dodge_perfect(pos: Vector2, charge_count: int)

## Emitted when the player casts skill_1 (AoE burst).
##
## [param pos] World-space position of the player (center of the AoE).
signal skill_1_cast(pos: Vector2)

## Emitted when the player takes damage.
##
## [param damage] Amount of damage taken.
## [param source_pos] World-space position of the damage source.
signal player_hit(damage: int, source_pos: Vector2)

## Emitted when the player dies (HP reaches 0).
##
## Consumed by: EnemyManager (freeze all AI), ShootingSystem (stop firing),
## VFX (death particles), Audio (death sound, BGM stop),
## InputSystem (state set to DEAD internally by DamageHealthSystem).
signal player_death()

## Emitted when an enemy is killed.
##
## [param type] EnemyType enum value (SMALL=0, MEDIUM=1, LARGE=2).
## [param position] World-space position of the killed enemy.
## [param index] Enemy index in the EnemyManager arrays.
signal enemy_killed(type: int, position: Vector2, index: int)

## Emitted when a new enemy is spawned.
##
## [param type] EnemyType enum value (SMALL=0, MEDIUM=1, LARGE=2).
## [param position] World-space position where the enemy was spawned.
## [param index] Enemy index in the EnemyManager arrays.
signal enemy_spawned(type: int, position: Vector2, index: int)
