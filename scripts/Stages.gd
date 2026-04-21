extends Control

@onready var _level_grid: GridContainer = %LevelGrid
@onready var _back_btn: Button = %BackBtn
@onready var _coins_label: Label = %CoinsLabel
@onready var _gems_label: Label = %GemsLabel

func _ready() -> void:
	_back_btn.pressed.connect(_on_back)
	GameManager.coins_changed.connect(func(v): _coins_label.text = "🪙 %d" % v)
	GameManager.gems_changed.connect(func(v): _gems_label.text = "💎 %d" % v)
	GameManager.level_stars_updated.connect(func(_id, _s): _build_levels())
	_coins_label.text = "🪙 %d" % GameManager.coins
	_gems_label.text = "💎 %d" % GameManager.gems
	call_deferred("_build_levels")

func _build_levels() -> void:
	for child in _level_grid.get_children():
		child.queue_free()
	for lvl in DataLoader.levels:
		var id: int = int(lvl.get("id", 1))
		var best: int = GameManager.get_best_stars(id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 110)
		btn.text = "%s\n%s\n%s" % [
			str(lvl.get("name", "Shift %d" % id)),
			_star_row(best),
			_level_blurb(lvl)
		]
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func(): _start_level(id))
		_level_grid.add_child(btn)

func _star_row(filled: int) -> String:
	var out := ""
	for i in 3:
		out += "★" if i < filled else "☆"
	return out

func _level_blurb(lvl: Dictionary) -> String:
	var orders: int = int(lvl.get("total_orders", 0))
	var mode: String = str(lvl.get("screen_mode", "single"))
	return "%d orders · %s screen" % [orders, mode]

func _start_level(id: int) -> void:
	GameManager.pending_level_id = id
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
