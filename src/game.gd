extends Node2D

func _ready() -> void:
	_safe_set($InputSystem, "player_node", $Player)
	_safe_set($Player/PlayerMovement, "input_system", $InputSystem)
	_safe_set($Player/ShootingSystem, "input_system", $InputSystem)
	_safe_set($Player/ShootingSystem, "enemy_manager", $EnemyManager)
	_safe_set($Player/ShootingSystem, "skill_system", $Player/SkillSystem)
	_safe_set($Player/DodgeSystem, "input_system", $InputSystem)
	_safe_set($Player/DodgeSystem, "player_movement", $Player/PlayerMovement)
	_safe_set($Player/DodgeSystem, "enemy_manager", $EnemyManager)
	_safe_set($Player/SkillSystem, "input_system", $InputSystem)
	_safe_set($Player/SkillSystem, "dodge_system", $Player/DodgeSystem)
	_safe_set($Player/DamageHealthSystem, "dodge_system", $Player/DodgeSystem)
	_safe_set($Player/DamageHealthSystem, "skill_system", $Player/SkillSystem)
	_safe_set($Player/DamageHealthSystem, "input_system", $InputSystem)
	_safe_set($Player/DiegeticUI, "damage_health_system", $Player/DamageHealthSystem)
	_safe_set($Player/DiegeticUI, "dodge_system", $Player/DodgeSystem)
	_safe_set($Player/DiegeticUI, "skill_system", $Player/SkillSystem)
	_safe_set($HUD, "wave_manager", $WaveManager)
	print("All systems wired")

func _safe_set(node: Node, prop: String, value: Node) -> void:
	if node and prop in node:
		node.set(prop, value)
