extends Node2D

func _ready() -> void:
	var inp: Node = $InputSystem
	var player: Node2D = $Player
	var move: Node = $Player/PlayerMovement
	var shoot: Node = $Player/ShootingSystem
	var dodge: Node = $Player/DodgeSystem
	var skill: Node = $Player/SkillSystem
	var damage: Node = $Player/DamageHealthSystem
	var enemy: Node = $EnemyManager
	var wave: Node = $WaveManager
	var vfx: Node = $VFXManager
	var cam: Camera2D = $Camera2D
	var diegetic: Node = $Player/DiegeticUI
	var hud: Node = $HUD

	inp.set("player_node", player)
	move.set("input_system", inp)
	shoot.set("input_system", inp)
	shoot.set("enemy_manager", enemy)
	shoot.set("skill_system", skill)
	dodge.set("input_system", inp)
	dodge.set("player_movement", move)
	dodge.set("enemy_manager", enemy)
	skill.set("input_system", inp)
	skill.set("dodge_system", dodge)
	damage.set("dodge_system", dodge)
	damage.set("skill_system", skill)
	damage.set("input_system", inp)
	diegetic.set("damage_health_system", damage)
	diegetic.set("dodge_system", dodge)
	diegetic.set("skill_system", skill)
	hud.set("wave_manager", wave)
	hud.set("game_manager", GameManager)

	print("All systems wired - Rift Reaction ready")
