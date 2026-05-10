extends Node2D

func _ready() -> void:
	var input_sys := $InputSystem
	var player := $Player
	var movement := $Player/PlayerMovement as PlayerMovement
	var shooting := $Player/ShootingSystem
	var dodge := $Player/DodgeSystem
	var skill := $Player/SkillSystem
	var damage := $Player/DamageHealthSystem
	var enemy_mgr := $EnemyManager
	var wave_mgr := $WaveManager
	var build_sys := $BuildSystem
	var vfx_mgr := $VFXManager
	var camera := $CameraSystem
	var diegetic := $Player/DiegeticUI
	var hud := $HUD

	input_sys.player_node = player
	movement.input_system = input_sys

	shooting.set("input_system", input_sys)
	shooting.set("enemy_manager", enemy_mgr)
	shooting.set("skill_system", skill)

	dodge.set("input_system", input_sys)
	dodge.set("player_movement", movement)
	dodge.set("enemy_manager", enemy_mgr)

	skill.set("input_system", input_sys)
	skill.set("dodge_system", dodge)

	damage.set("dodge_system", dodge)
	damage.set("skill_system", skill)
	damage.set("input_system", input_sys)

	wave_mgr.set("enemy_manager", enemy_mgr)
	build_sys.set("wave_manager", wave_mgr)

	camera.follow_target = player

	diegetic.set("damage_health_system", damage)
	diegetic.set("dodge_system", dodge)
	diegetic.set("skill_system", skill)

	hud.set("wave_manager", wave_mgr)

	print("Game systems initialized")
