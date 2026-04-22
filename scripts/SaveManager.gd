extends Node

const SAVE_PATH := "user://save.json"

func _ready() -> void:
	load_game()
	GameManager.coins_changed.connect(func(_v): save_game())
	GameManager.gems_changed.connect(func(_v): save_game())
	GameManager.level_stars_updated.connect(func(_id, _s): save_game())
	MissionManager.mission_claimed.connect(func(_id): save_game())

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: could not open %s" % SAVE_PATH)
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: save file is not a dictionary")
		return
	var data: Dictionary = parsed
	GameManager.coins = int(data.get("coins", 0))
	GameManager.gems = int(data.get("gems", 0))
	var stars_raw: Variant = data.get("level_best_stars", {})
	if typeof(stars_raw) == TYPE_DICTIONARY:
		GameManager.level_best_stars = stars_raw
	MissionManager.current_index = int(data.get("mission_index", 0))
	MissionManager.emit_signal("mission_progress_changed")

func save_game() -> void:
	var data := {
		"coins": GameManager.coins,
		"gems": GameManager.gems,
		"level_best_stars": GameManager.level_best_stars,
		"mission_index": MissionManager.current_index,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data))
	file.close()

func reset() -> void:
	GameManager.coins = 0
	GameManager.gems = 0
	GameManager.level_best_stars = {}
	GameManager.emit_signal("coins_changed", 0)
	GameManager.emit_signal("gems_changed", 0)
	MissionManager.reset()
	save_game()
