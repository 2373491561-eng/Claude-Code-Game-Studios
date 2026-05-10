class_name SaveManager extends Node

const SAVE_PATH = "user://save_data.json"
const SAVE_TEMP_PATH = "user://save_data.tmp"

var data: Dictionary = {}

func _ready() -> void:
	_load()

func _default_data() -> Dictionary:
	return {
		version = 1,
		last_updated = 0,
		meta_progression = {total_points = 0, highest_wave = 0, unlocks = []},
		settings = {master_volume = 1.0, bgm_volume = 0.7, sfx_volume = 0.85},
	}

func _load() -> void:
	data = _default_data()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: Cannot open save file — using defaults")
		return
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed == null or not parsed is Dictionary:
		push_warning("SaveManager: Save file corrupted — using defaults")
		return
	_merge(parsed)

func save() -> void:
	data.last_updated = Time.get_unix_time_from_system()
	var json := JSON.stringify(data, "\t")
	var tmp := FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)
	if tmp == null:
		push_error("SaveManager: Cannot write temp save file")
		return
	tmp.store_string(json)
	tmp.close()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.rename_absolute(SAVE_TEMP_PATH, SAVE_PATH)

func _merge(loaded: Dictionary) -> void:
	if loaded.has("version"): data.version = loaded.version
	if loaded.has("meta_progression") and loaded.meta_progression is Dictionary:
		var mp = loaded.meta_progression
		if mp.has("total_points"): data.meta_progression.total_points = mp.total_points
		if mp.has("highest_wave"): data.meta_progression.highest_wave = mp.highest_wave
		if mp.has("unlocks"): data.meta_progression.unlocks = mp.unlocks
	if loaded.has("settings") and loaded.settings is Dictionary:
		var s = loaded.settings
		if s.has("master_volume"): data.settings.master_volume = s.master_volume
		if s.has("bgm_volume"): data.settings.bgm_volume = s.bgm_volume
		if s.has("sfx_volume"): data.settings.sfx_volume = s.sfx_volume

func get_meta_points() -> int:
	return data.meta_progression.total_points

func add_meta_points(amount: int) -> void:
	data.meta_progression.total_points += amount

func get_highest_wave() -> int:
	return data.meta_progression.highest_wave

func set_highest_wave(wave: int) -> void:
	if wave > data.meta_progression.highest_wave:
		data.meta_progression.highest_wave = wave

func get_unlocks() -> Array:
	return data.meta_progression.unlocks

func add_unlock(upgrade_id: String) -> void:
	if upgrade_id not in data.meta_progression.unlocks:
		data.meta_progression.unlocks.append(upgrade_id)

func get_setting(key: String, default = null):
	return data.settings.get(key, default)

func set_setting(key: String, value) -> void:
	data.settings[key] = value
	save()
