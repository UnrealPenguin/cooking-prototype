extends Node

const SAVE_PATH := "user://save.json"

func _ready() -> void:
	_load()
	GameManager.coins_changed.connect(func(_v): _save())
	GameManager.stars_changed.connect(func(_v): _save())
	GameManager.gems_changed.connect(func(_v): _save())

func _load() -> void:
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
	GameManager.stars_total = int(data.get("stars_total", 0))
	GameManager.gems = int(data.get("gems", 0))

func _save() -> void:
	var data := {
		"coins": GameManager.coins,
		"stars_total": GameManager.stars_total,
		"gems": GameManager.gems,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data))
	file.close()

func reset() -> void:
	GameManager.coins = 0
	GameManager.stars_total = 0
	GameManager.gems = 0
	_save()
