extends Control

@onready var _mission_list: VBoxContainer = %MissionList
@onready var _back_btn: Button = %BackBtn
@onready var _coins_label: Label = %CoinsLabel
@onready var _gems_label: Label = %GemsLabel

func _ready() -> void:
	_back_btn.pressed.connect(_on_back)
	GameManager.coins_changed.connect(func(v): _coins_label.text = "🪙 %d" % v)
	GameManager.gems_changed.connect(func(v): _gems_label.text = "💎 %d" % v)
	MissionManager.mission_progress_changed.connect(_rebuild)
	_coins_label.text = "🪙 %d" % GameManager.coins
	_gems_label.text = "💎 %d" % GameManager.gems
	call_deferred("_rebuild")

func _rebuild() -> void:
	for child in _mission_list.get_children():
		child.queue_free()
	if not MissionManager.has_active_mission():
		_mission_list.add_child(_make_done_card())
		return
	_mission_list.add_child(_make_mission_card())

func _make_mission_card() -> Control:
	var m: Dictionary = MissionManager.get_current_mission()
	var progress: Dictionary = MissionManager.get_progress()
	var current: int = int(progress.get("current", 0))
	var target: int = int(progress.get("target", 1))
	var claimable: bool = bool(progress.get("claimable", false))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 130)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)

	var title := Label.new()
	title.text = str(m.get("description", ""))
	title.add_theme_font_size_override("font_size", 22)
	info.add_child(title)

	var progress_label := Label.new()
	progress_label.text = "Progress: %d / %d" % [current, target]
	progress_label.add_theme_font_size_override("font_size", 16)
	info.add_child(progress_label)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = target
	bar.value = current
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	info.add_child(bar)

	var reward_col := VBoxContainer.new()
	reward_col.add_theme_constant_override("separation", 6)
	reward_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(reward_col)

	var reward_label := Label.new()
	reward_label.text = _reward_text(m)
	reward_label.add_theme_font_size_override("font_size", 18)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_col.add_child(reward_label)

	var claim_btn := Button.new()
	claim_btn.text = "Claim" if claimable else "In Progress"
	claim_btn.disabled = not claimable
	claim_btn.custom_minimum_size = Vector2(140, 44)
	claim_btn.pressed.connect(_on_claim)
	reward_col.add_child(claim_btn)

	return panel

func _make_done_card() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 100)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var label := Label.new()
	label.text = "All missions complete! More on the way."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	margin.add_child(label)
	return panel

func _reward_text(m: Dictionary) -> String:
	var parts: Array[String] = []
	var coins := int(m.get("reward_coins", 0))
	var gems := int(m.get("reward_gems", 0))
	if coins > 0:
		parts.append("🪙 %d" % coins)
	if gems > 0:
		parts.append("💎 %d" % gems)
	if parts.is_empty():
		return "—"
	return "  ".join(parts)

func _on_claim() -> void:
	MissionManager.claim_current()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
