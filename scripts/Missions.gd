extends Control

@onready var _mission_list: VBoxContainer = %MissionList
@onready var _back_btn: Button = %BackBtn
@onready var _coins_label: Label = %CoinsLabel
@onready var _gems_label: Label = %GemsLabel
@onready var _main_tab_btn: Button = %MainTabBtn
@onready var _daily_tab_btn: Button = %DailyTabBtn
@onready var _daily_reset_label: Label = %DailyResetLabel

var _active_tab: String = "main"

func _ready() -> void:
	_back_btn.pressed.connect(_on_back)
	_main_tab_btn.pressed.connect(func(): _switch_tab("main"))
	_daily_tab_btn.pressed.connect(func(): _switch_tab("daily"))
	GameManager.coins_changed.connect(func(v): _coins_label.text = "🪙 %d" % v)
	GameManager.gems_changed.connect(func(v): _gems_label.text = "💎 %d" % v)
	MissionManager.mission_progress_changed.connect(_rebuild)
	MissionManager.daily_reset.connect(_rebuild)
	_coins_label.text = "🪙 %d" % GameManager.coins
	_gems_label.text = "💎 %d" % GameManager.gems
	MissionManager.check_daily_reset()
	call_deferred("_rebuild")

func _switch_tab(tab: String) -> void:
	_active_tab = tab
	_main_tab_btn.button_pressed = tab == "main"
	_daily_tab_btn.button_pressed = tab == "daily"
	_rebuild()

func _rebuild() -> void:
	for child in _mission_list.get_children():
		child.queue_free()
	if _active_tab == "daily":
		_daily_reset_label.text = "Resets daily · %s" % MissionManager.daily_date
		_build_daily()
	else:
		_daily_reset_label.text = ""
		_build_main()

func _build_main() -> void:
	if not MissionManager.has_active_mission():
		_mission_list.add_child(_make_done_card("All missions complete! More on the way."))
		return
	_mission_list.add_child(_make_main_card())

func _build_daily() -> void:
	var entries: Array = MissionManager.get_daily_entries()
	if entries.is_empty():
		_mission_list.add_child(_make_done_card("No daily missions today."))
		return
	for entry in entries:
		_mission_list.add_child(_make_daily_card(entry))

func _make_main_card() -> Control:
	var m: Dictionary = MissionManager.get_current_mission()
	var progress: Dictionary = MissionManager.get_progress()
	return _build_card(
		str(m.get("description", "")),
		int(progress.get("current", 0)),
		int(progress.get("target", 1)),
		bool(progress.get("claimable", false)),
		false,
		_reward_text(m),
		_on_claim_main
	)

func _make_daily_card(entry: Dictionary) -> Control:
	var template: Dictionary = entry.get("template", {})
	var id: String = str(template.get("id", ""))
	return _build_card(
		str(template.get("description", "")),
		int(entry.get("current", 0)),
		int(entry.get("target", 1)),
		bool(entry.get("claimable", false)),
		bool(entry.get("claimed", false)),
		_reward_text(template),
		func(): MissionManager.claim_daily(id)
	)

func _build_card(desc: String, current: int, target: int, claimable: bool, claimed: bool, reward: String, on_claim: Callable) -> Control:
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
	title.text = desc
	title.add_theme_font_size_override("font_size", 22)
	info.add_child(title)

	var progress_label := Label.new()
	progress_label.text = "Progress: %d / %d" % [current, target]
	progress_label.add_theme_font_size_override("font_size", 16)
	info.add_child(progress_label)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max(target, 1)
	bar.value = current
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	info.add_child(bar)

	var reward_col := VBoxContainer.new()
	reward_col.add_theme_constant_override("separation", 6)
	reward_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(reward_col)

	var reward_label := Label.new()
	reward_label.text = reward
	reward_label.add_theme_font_size_override("font_size", 18)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_col.add_child(reward_label)

	var btn := Button.new()
	if claimed:
		btn.text = "Claimed"
		btn.disabled = true
	elif claimable:
		btn.text = "Claim"
		btn.disabled = false
	else:
		btn.text = "In Progress"
		btn.disabled = true
	btn.custom_minimum_size = Vector2(140, 44)
	btn.pressed.connect(on_claim)
	reward_col.add_child(btn)

	return panel

func _make_done_card(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 100)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var label := Label.new()
	label.text = text
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

func _on_claim_main() -> void:
	MissionManager.claim_current()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
