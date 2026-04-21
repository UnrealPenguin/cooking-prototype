extends Control

const CuttingBoardScene := preload("res://scenes/CuttingBoard.tscn")
const ApplianceScene := preload("res://scenes/Appliance.tscn")
const OrderCardScene := preload("res://scenes/OrderCard.tscn")

const CONTAINER_CAPACITY := 3

@onready var _root: VBoxContainer = %Root
@onready var _assembly_view: AssemblyView = $AssemblyView
@onready var _level_complete: Control = %LevelComplete
@onready var _level_summary: Label = %Summary
@onready var _restart_btn: Button = %RestartBtn
@onready var _next_btn: Button = %NextBtn
@onready var _home_btn: Button = %HomeBtn
@onready var _tutorial: Control = %Tutorial
@onready var _tutorial_start_btn: Button = %StartBtn
@onready var _pause_panel: Control = %PausePanel
@onready var _resume_btn: Button = %ResumeBtn
@onready var _pause_settings_btn: Button = %PauseSettingsBtn
@onready var _quit_btn: Button = %QuitBtn
@onready var _settings_sub_panel: Control = %SettingsSubPanel
@onready var _pause_volume_slider: HSlider = %VolumeSlider
@onready var _pause_volume_value: Label = %VolumeValue
@onready var _pause_fullscreen_check: CheckBox = %FullscreenCheck
@onready var _close_sub_settings_btn: Button = %CloseSubSettingsBtn

var _top_bar: HBoxContainer
var _level_title_label: Label
var _order_strip: HBoxContainer
var _stats_label: Label
var _pause_btn: Button

var _screen_area: Control
var _pages_holder: Control
var _swipe_left_hint: Label
var _swipe_right_hint: Label

var _bottom_bar: HBoxContainer
var _ready_tray_box: HBoxContainer

var _pages: Array[Control] = []
var _current_page: int = 0
var _dragging: bool = false
var _drag_start_x: float = 0.0
var _drag_start_offset: float = 0.0
const SWIPE_THRESHOLD := 80.0

var _active_orders: Array[OrderCard] = []
var _ready_tray: Dictionary = {}  # "ing:state" -> int count
var _appliances_ui: Array[Appliance] = []
var _cutting_board: Node
var _raw_buttons: Dictionary = {}  # ingredient_id -> Button
var _container_labels: Dictionary = {}  # ingredient_id -> Label

var _spawn_timer: float = 0.0
var _orders_spawned: int = 0
var _level_active: bool = false
var _next_level_id: int = 1
var _prep_time_left: float = 0.0
var _prep_label: Label

var _stage_coins: int = 0
var _stage_elapsed: float = 0.0
var _stage_burnt: bool = false
var _stage_angry: bool = false

func _ready() -> void:
	_build_layout()
	_assembly_view.served.connect(_on_serve)
	_assembly_view.cancelled.connect(_on_assemble_cancel)
	_restart_btn.pressed.connect(_on_restart)
	_next_btn.pressed.connect(_on_next_level)
	_home_btn.pressed.connect(_on_quit_to_home)
	_tutorial_start_btn.pressed.connect(_on_tutorial_dismiss)
	_resume_btn.pressed.connect(_on_resume)
	_pause_settings_btn.pressed.connect(func(): _settings_sub_panel.visible = true)
	_close_sub_settings_btn.pressed.connect(func(): _settings_sub_panel.visible = false)
	_quit_btn.pressed.connect(_on_quit_to_home)
	_pause_volume_slider.value_changed.connect(_on_pause_volume_changed)
	_pause_fullscreen_check.toggled.connect(_on_pause_fullscreen_toggled)
	var bus_db: float = AudioServer.get_bus_volume_db(0)
	_pause_volume_slider.value = clamp(db_to_linear(bus_db), 0.0, 1.0) * 100.0
	_on_pause_volume_changed(_pause_volume_slider.value)
	_pause_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	GameManager.level_started.connect(_on_level_started)
	GameManager.level_completed.connect(_on_level_completed)
	get_viewport().size_changed.connect(_on_viewport_resized)
	# Defer start so autoloads finish loading
	call_deferred("_start_first_level")

func _start_first_level() -> void:
	_next_level_id = GameManager.pending_level_id
	GameManager.start_level(_next_level_id)

func _build_layout() -> void:
	# Top bar
	_top_bar = HBoxContainer.new()
	_top_bar.custom_minimum_size = Vector2(0, 190)
	_top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar.add_theme_constant_override("separation", 8)
	_root.add_child(_top_bar)

	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(160, 0)
	_top_bar.add_child(info_panel)
	var info_vb := VBoxContainer.new()
	info_panel.add_child(info_vb)
	_level_title_label = Label.new()
	_level_title_label.text = "Shift"
	_level_title_label.add_theme_font_size_override("font_size", 16)
	info_vb.add_child(_level_title_label)
	_stats_label = Label.new()
	_stats_label.text = "Coins: 0"
	info_vb.add_child(_stats_label)

	_order_strip = HBoxContainer.new()
	_order_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_strip.add_theme_constant_override("separation", 8)
	_top_bar.add_child(_order_strip)

	_pause_btn = Button.new()
	_pause_btn.text = "⏸"
	_pause_btn.custom_minimum_size = Vector2(56, 56)
	_pause_btn.add_theme_font_size_override("font_size", 22)
	_pause_btn.pressed.connect(_on_pause)
	_top_bar.add_child(_pause_btn)

	# Screen area (pages)
	_screen_area = Control.new()
	_screen_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen_area.clip_contents = true
	_screen_area.mouse_filter = Control.MOUSE_FILTER_PASS
	_screen_area.gui_input.connect(_on_screen_input)
	_root.add_child(_screen_area)

	_pages_holder = Control.new()
	_pages_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_screen_area.add_child(_pages_holder)

	_swipe_left_hint = Label.new()
	_swipe_left_hint.text = "◀"
	_swipe_left_hint.add_theme_font_size_override("font_size", 48)
	_swipe_left_hint.modulate = Color(1, 1, 1, 0.35)
	_swipe_left_hint.anchor_left = 0
	_swipe_left_hint.anchor_top = 0.5
	_swipe_left_hint.offset_left = 10
	_swipe_left_hint.offset_top = -24
	_swipe_left_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_area.add_child(_swipe_left_hint)

	_swipe_right_hint = Label.new()
	_swipe_right_hint.text = "▶"
	_swipe_right_hint.add_theme_font_size_override("font_size", 48)
	_swipe_right_hint.modulate = Color(1, 1, 1, 0.35)
	_swipe_right_hint.anchor_left = 1
	_swipe_right_hint.anchor_top = 0.5
	_swipe_right_hint.offset_left = -50
	_swipe_right_hint.offset_top = -24
	_swipe_right_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_area.add_child(_swipe_right_hint)

	# Bottom ready tray
	_bottom_bar = HBoxContainer.new()
	_bottom_bar.custom_minimum_size = Vector2(0, 70)
	_bottom_bar.add_theme_constant_override("separation", 6)
	_root.add_child(_bottom_bar)

	var tray_label := Label.new()
	tray_label.text = "READY:"
	tray_label.add_theme_font_size_override("font_size", 14)
	_bottom_bar.add_child(tray_label)

	_ready_tray_box = HBoxContainer.new()
	_ready_tray_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_tray_box.add_theme_constant_override("separation", 6)
	_bottom_bar.add_child(_ready_tray_box)

	_prep_label = Label.new()
	_prep_label.visible = false
	_prep_label.add_theme_font_size_override("font_size", 14)
	_prep_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	info_vb.add_child(_prep_label)

func _on_viewport_resized() -> void:
	_relayout_pages()

func _on_level_started(lvl: Dictionary) -> void:
	_level_active = true
	_orders_spawned = 0
	_spawn_timer = float(lvl.get("spawn_interval", 6.0)) - float(lvl.get("initial_delay", 1.0))
	_prep_time_left = float(lvl.get("prep_time", 0.0))
	_stage_coins = 0
	_stage_elapsed = 0.0
	_stage_burnt = false
	_stage_angry = false
	_update_prep_overlay()
	_active_orders.clear()
	_ready_tray.clear()
	_level_title_label.text = str(lvl.get("name", "Shift"))
	_clear_children(_order_strip)
	_clear_children(_pages_holder)
	_clear_children(_ready_tray_box)
	_pages.clear()
	_appliances_ui.clear()
	_cutting_board = null
	_raw_buttons.clear()
	_container_labels.clear()
	_current_page = 0
	_update_stats()

	var mode: String = lvl.get("screen_mode", "single")
	if mode == "single":
		var page := _build_combined_page(lvl)
		_pages_holder.add_child(page)
		_pages.append(page)
	else:
		var prep_page := _build_prep_page(lvl)
		var cook_page := _build_cook_page(lvl)
		_pages_holder.add_child(prep_page)
		_pages_holder.add_child(cook_page)
		_pages.append(prep_page)
		_pages.append(cook_page)

	_refresh_ready_tray_ui()
	_refresh_prep_ui()
	call_deferred("_relayout_pages")

	if bool(lvl.get("show_swipe_tutorial", false)):
		_tutorial.visible = true

func _relayout_pages() -> void:
	var area_size: Vector2 = _screen_area.size
	if area_size.x <= 0 or area_size.y <= 0:
		return
	for i in _pages.size():
		var page := _pages[i]
		page.position = Vector2(i * area_size.x, 0)
		page.custom_minimum_size = area_size
		page.size = area_size
	_pages_holder.position = Vector2(-_current_page * area_size.x, 0)
	_update_swipe_hints()

func _update_swipe_hints() -> void:
	var multi := _pages.size() > 1
	_swipe_left_hint.visible = multi and _current_page > 0
	_swipe_right_hint.visible = multi and _current_page < _pages.size() - 1

func _build_prep_page(lvl: Dictionary) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.22, 0.2, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	root.add_child(margin)
	var vb := VBoxContainer.new()
	margin.add_child(vb)
	var title := Label.new()
	title.text = "PREP STATION"
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)
	_build_prep_section(vb, lvl)
	return root

func _build_cook_page(lvl: Dictionary) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	var bg := ColorRect.new()
	bg.color = Color(0.22, 0.17, 0.15, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	root.add_child(margin)
	var vb := VBoxContainer.new()
	margin.add_child(vb)
	var title := Label.new()
	title.text = "COOKING STATION"
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)

	var appliance_ids: Array = lvl.get("appliances", [])
	var place_box := HBoxContainer.new()
	place_box.add_theme_constant_override("separation", 8)
	vb.add_child(place_box)
	var place_label := Label.new()
	place_label.text = "Place raw:"
	place_box.add_child(place_label)
	var cookable_ids := _cookable_ingredient_ids_for_appliances(appliance_ids)
	for id in cookable_ids:
		var ing := DataLoader.get_ingredient(id)
		var btn := Button.new()
		btn.text = str(ing.get("label", id))
		btn.custom_minimum_size = Vector2(110, 44)
		btn.pressed.connect(func(): _place_on_appliance(id))
		place_box.add_child(btn)

	var appliances_box := HBoxContainer.new()
	appliances_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	appliances_box.add_theme_constant_override("separation", 10)
	vb.add_child(appliances_box)
	for app_id in appliance_ids:
		var app_data := DataLoader.get_appliance(app_id)
		if app_data.is_empty():
			continue
		var app := ApplianceScene.instantiate() as Appliance
		app.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		appliances_box.add_child(app)
		app.setup(app_id, app_data)
		app.item_cooked.connect(_on_cooked)
		app.item_burnt.connect(_on_burnt)
		_appliances_ui.append(app)
	return root

func _build_combined_page(lvl: Dictionary) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.20, 0.18, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	root.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	var prep_title := Label.new()
	prep_title.text = "PREP"
	prep_title.add_theme_font_size_override("font_size", 20)
	vb.add_child(prep_title)
	_build_prep_section(vb, lvl)

	var cook_title := Label.new()
	cook_title.text = "COOK"
	cook_title.add_theme_font_size_override("font_size", 20)
	vb.add_child(cook_title)

	var appliance_ids: Array = lvl.get("appliances", [])
	var place_box := HBoxContainer.new()
	place_box.add_theme_constant_override("separation", 8)
	vb.add_child(place_box)
	var place_label := Label.new()
	place_label.text = "Place raw:"
	place_box.add_child(place_label)
	var cookable_ids := _cookable_ingredient_ids_for_appliances(appliance_ids)
	for id in cookable_ids:
		var ing := DataLoader.get_ingredient(id)
		var btn := Button.new()
		btn.text = str(ing.get("label", id))
		btn.custom_minimum_size = Vector2(110, 44)
		btn.pressed.connect(func(): _place_on_appliance(id))
		place_box.add_child(btn)

	var appliances_box := HBoxContainer.new()
	appliances_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	appliances_box.add_theme_constant_override("separation", 10)
	vb.add_child(appliances_box)
	for app_id in appliance_ids:
		var app_data := DataLoader.get_appliance(app_id)
		if app_data.is_empty():
			continue
		var app := ApplianceScene.instantiate() as Appliance
		app.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		appliances_box.add_child(app)
		app.setup(app_id, app_data)
		app.item_cooked.connect(_on_cooked)
		app.item_burnt.connect(_on_burnt)
		_appliances_ui.append(app)

	return root

func _cookable_ingredient_ids_for_appliances(appliance_ids: Array) -> Array:
	var out: Array = []
	for id in DataLoader.ingredients.keys():
		var ing: Dictionary = DataLoader.ingredients[id]
		if bool(ing.get("needs_cook", false)) and ing.get("appliance", "") in appliance_ids:
			out.append(id)
	return out

func _place_on_appliance(ingredient_id: String) -> void:
	var ing := DataLoader.get_ingredient(ingredient_id)
	for app in _appliances_ui:
		if app.try_place(ingredient_id, ing):
			return

func _build_prep_section(vb: VBoxContainer, lvl: Dictionary) -> void:
	var raw_row := HBoxContainer.new()
	raw_row.add_theme_constant_override("separation", 8)
	vb.add_child(raw_row)
	var raw_label := Label.new()
	raw_label.text = "Raw:"
	raw_row.add_child(raw_label)
	for ing_id in lvl.get("prep_ingredients", []):
		var id: String = str(ing_id)
		var ing := DataLoader.get_ingredient(id)
		if ing.is_empty():
			continue
		var btn := Button.new()
		btn.text = str(ing.get("label", id))
		btn.custom_minimum_size = Vector2(110, 44)
		btn.pressed.connect(func(): _on_raw_pressed(id))
		raw_row.add_child(btn)
		_raw_buttons[id] = btn

	var board_row := HBoxContainer.new()
	board_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(board_row)
	_cutting_board = CuttingBoardScene.instantiate()
	board_row.add_child(_cutting_board)
	_cutting_board.chopped.connect(_on_chopped)
	_cutting_board.state_changed.connect(_refresh_prep_ui)

	var cont_row := HBoxContainer.new()
	cont_row.add_theme_constant_override("separation", 8)
	vb.add_child(cont_row)
	var cont_title := Label.new()
	cont_title.text = "Ready:"
	cont_row.add_child(cont_title)
	for ing_id in lvl.get("prep_ingredients", []):
		var id: String = str(ing_id)
		var ing := DataLoader.get_ingredient(id)
		if ing.is_empty():
			continue
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(140, 52)
		var mb := MarginContainer.new()
		mb.add_theme_constant_override("margin_left", 6)
		mb.add_theme_constant_override("margin_right", 6)
		mb.add_theme_constant_override("margin_top", 4)
		mb.add_theme_constant_override("margin_bottom", 4)
		panel.add_child(mb)
		var hb := HBoxContainer.new()
		mb.add_child(hb)
		var color := ColorRect.new()
		color.color = DataLoader.parse_color(str(ing.get("color", "#CCCCCC"))).lightened(0.15)
		color.custom_minimum_size = Vector2(20, 20)
		hb.add_child(color)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 13)
		hb.add_child(lbl)
		cont_row.add_child(panel)
		_container_labels[id] = lbl

func _on_raw_pressed(ing_id: String) -> void:
	if _cutting_board == null or not _cutting_board.is_empty():
		return
	if _container_count(ing_id) >= CONTAINER_CAPACITY:
		return
	var ing := DataLoader.get_ingredient(ing_id)
	if ing.is_empty() or not bool(ing.get("needs_prep", false)):
		return
	_cutting_board.place(ing_id, ing)

func _on_chopped(ingredient_id: String) -> void:
	_add_to_tray(ingredient_id, "prepped", 1)

func _on_cooked(ingredient_id: String) -> void:
	_add_to_tray(ingredient_id, "cooked", 1)

func _container_count(ing_id: String) -> int:
	return int(_ready_tray.get("%s:prepped" % ing_id, 0))

func _refresh_prep_ui() -> void:
	if _cutting_board == null:
		return
	var board_busy: bool = not _cutting_board.is_empty()
	for id in _raw_buttons.keys():
		var btn: Button = _raw_buttons[id]
		var full := _container_count(id) >= CONTAINER_CAPACITY
		btn.disabled = board_busy or full
	for id in _container_labels.keys():
		var lbl: Label = _container_labels[id]
		var ing := DataLoader.get_ingredient(id)
		var text: String = str(ing.get("prepped_label", ing.get("label", id)))
		lbl.text = " %s %d/%d" % [text, _container_count(id), CONTAINER_CAPACITY]

func _add_to_tray(ingredient_id: String, state: String, amount: int) -> void:
	var key := "%s:%s" % [ingredient_id, state]
	_ready_tray[key] = int(_ready_tray.get(key, 0)) + amount
	_refresh_ready_tray_ui()
	_refresh_order_assemble_buttons()
	_refresh_prep_ui()

func _consume_from_tray(components: Array) -> void:
	var grouped := _group_components(components)
	for key in grouped.keys():
		_ready_tray[key] = max(0, int(_ready_tray.get(key, 0)) - int(grouped[key]))
		if int(_ready_tray[key]) == 0:
			_ready_tray.erase(key)
	_refresh_ready_tray_ui()
	_refresh_order_assemble_buttons()
	_refresh_prep_ui()

func _group_components(components: Array) -> Dictionary:
	var out: Dictionary = {}
	for comp in components:
		var key := "%s:%s" % [comp.get("ingredient", ""), comp.get("state", "")]
		out[key] = int(out.get(key, 0)) + 1
	return out

func _tray_has_components(components: Array) -> bool:
	var grouped := _group_components(components)
	for key in grouped.keys():
		if int(_ready_tray.get(key, 0)) < int(grouped[key]):
			return false
	return true

func _refresh_ready_tray_ui() -> void:
	_clear_children(_ready_tray_box)
	for key in _ready_tray.keys():
		var parts: PackedStringArray = key.split(":")
		var ing_id: String = parts[0]
		var state: String = parts[1]
		var ing := DataLoader.get_ingredient(ing_id)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(140, 56)
		var mb := MarginContainer.new()
		mb.add_theme_constant_override("margin_left", 6)
		mb.add_theme_constant_override("margin_right", 6)
		mb.add_theme_constant_override("margin_top", 4)
		mb.add_theme_constant_override("margin_bottom", 4)
		panel.add_child(mb)
		var hb := HBoxContainer.new()
		mb.add_child(hb)
		var color := ColorRect.new()
		color.color = DataLoader.parse_color(str(ing.get("color", "#CCCCCC")))
		if state == "cooked":
			color.color = color.color.lightened(0.15)
		color.custom_minimum_size = Vector2(22, 22)
		hb.add_child(color)
		var lbl := Label.new()
		var text: String = ing.get("label", ing_id)
		if state == "prepped":
			text = ing.get("prepped_label", text)
		elif state == "cooked":
			text = ing.get("cooked_label", text)
		lbl.text = "  %s x%d" % [text, int(_ready_tray[key])]
		lbl.add_theme_font_size_override("font_size", 12)
		hb.add_child(lbl)
		_ready_tray_box.add_child(panel)

func _refresh_order_assemble_buttons() -> void:
	for card in _active_orders:
		_update_card_assemble_state(card)

func _update_card_assemble_state(card: OrderCard) -> void:
	var btn := card.find_child("AssembleBtn", true, false) as Button
	if btn == null:
		return
	btn.disabled = not _tray_has_components(card.recipe.get("components", []))

func _clear_children(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()

func _update_stats() -> void:
	_stats_label.text = "Coins: %d" % _stage_coins

func _process(delta: float) -> void:
	if not _level_active:
		return
	if _prep_time_left > 0.0:
		_prep_time_left = max(0.0, _prep_time_left - delta)
		_update_prep_overlay()
		return
	_stage_elapsed += delta
	if _orders_spawned < GameManager.total_orders():
		_spawn_timer += delta
		var interval := float(GameManager.current_level.get("spawn_interval", 6.0))
		var max_active := int(GameManager.current_level.get("max_simultaneous_orders", 1))
		if _spawn_timer >= interval and _active_orders.size() < max_active:
			_spawn_timer = 0.0
			_spawn_order()

func _update_prep_overlay() -> void:
	if _prep_time_left <= 0.0:
		_prep_label.visible = false
		return
	_prep_label.visible = true
	var seconds: int = int(ceil(_prep_time_left))
	_prep_label.text = "PREP: %ds" % seconds

func _spawn_order() -> void:
	var pool: Array = GameManager.current_level.get("recipes", [])
	if pool.is_empty():
		return
	var recipe_id: String = pool[randi() % pool.size()]
	var recipe := DataLoader.get_recipe(recipe_id)
	if recipe.is_empty():
		return
	var card := OrderCardScene.instantiate() as OrderCard
	_order_strip.add_child(card)
	card.setup(recipe_id, recipe)
	card.expired.connect(_on_order_expired)
	# Add Assemble button to the card
	var btn := Button.new()
	btn.name = "AssembleBtn"
	btn.text = "Assemble"
	btn.disabled = true
	btn.pressed.connect(func(): _on_assemble_pressed(card))
	var vb := card.get_node("Inner/Margin/VB")
	vb.add_child(btn)
	_active_orders.append(card)
	_orders_spawned += 1
	_update_card_assemble_state(card)

func _on_order_expired(card: OrderCard) -> void:
	if not _active_orders.has(card):
		return
	_active_orders.erase(card)
	card.queue_free()
	_stage_angry = true
	GameManager.record_order_result(false)

func _on_assemble_pressed(card: OrderCard) -> void:
	if not _tray_has_components(card.recipe.get("components", [])):
		return
	_assembly_view.open_for(card)

func _on_assemble_cancel() -> void:
	pass

func _on_serve(card: OrderCard) -> void:
	if card == null or not _active_orders.has(card):
		return
	var coins := card.coins_for_current_time()
	var ratio: float = card.time_left / card.time_limit if card.time_limit > 0.0 else 0.0
	if ratio < 0.33:
		_stage_angry = true
	_stage_coins += coins
	GameManager.add_coins(coins)
	_update_stats()
	_consume_from_tray(card.recipe.get("components", []))
	_active_orders.erase(card)
	card.stop()
	card.queue_free()
	GameManager.record_order_result(true)

func _on_burnt(_ingredient_id: String) -> void:
	_stage_burnt = true

func _on_level_completed(summary: Dictionary) -> void:
	_level_active = false
	var lvl_id := int(GameManager.current_level.get("id", 1))
	var time_target: float = float(GameManager.current_level.get("time_target_seconds", 9999.0))
	var completed: int = int(summary.get("completed", 0))
	var failed: int = int(summary.get("failed", 0))

	var no_burn := not _stage_burnt
	var no_angry := not _stage_angry
	var under_time := _stage_elapsed <= time_target
	var stars := 0
	if completed > 0:
		stars = int(no_burn) + int(no_angry) + int(under_time)

	GameManager.update_best_stars(lvl_id, stars)

	var star_row := ""
	for i in 3:
		star_row += "★" if i < stars else "☆"
	var lines: Array[String] = []
	lines.append("%s  (%d/3)" % [star_row, stars])
	lines.append("")
	lines.append("%s No burnt items" % ("✓" if no_burn else "✗"))
	lines.append("%s No angry customers" % ("✓" if no_angry else "✗"))
	lines.append("%s Under %ds  (took %ds)" % [
		"✓" if under_time else "✗",
		int(time_target),
		int(ceil(_stage_elapsed))
	])
	lines.append("")
	lines.append("Served: %d   Failed: %d" % [completed, failed])
	lines.append("Coins earned: %d" % _stage_coins)
	_level_summary.text = "\n".join(lines)

	var has_next := DataLoader.get_level(lvl_id + 1).size() > 0
	_next_btn.visible = has_next
	_level_complete.visible = true

func _on_restart() -> void:
	_level_complete.visible = false
	_clear_active_ui()
	GameManager.start_level(_next_level_id)

func _on_next_level() -> void:
	_next_level_id = int(GameManager.current_level.get("id", 1)) + 1
	_level_complete.visible = false
	_clear_active_ui()
	GameManager.start_level(_next_level_id)

func _on_tutorial_dismiss() -> void:
	_tutorial.visible = false

func _on_pause() -> void:
	_settings_sub_panel.visible = false
	_pause_panel.visible = true
	get_tree().paused = true

func _on_resume() -> void:
	_pause_panel.visible = false
	_settings_sub_panel.visible = false
	get_tree().paused = false

func _on_quit_to_home() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Home.tscn")

func _on_pause_volume_changed(value: float) -> void:
	var linear: float = value / 100.0
	AudioServer.set_bus_volume_db(0, linear_to_db(max(linear, 0.0001)))
	_pause_volume_value.text = "%d%%" % int(round(value))

func _on_pause_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func _clear_active_ui() -> void:
	for c in _active_orders:
		c.queue_free()
	_active_orders.clear()
	_ready_tray.clear()

# Swipe handling
func _on_screen_input(event: InputEvent) -> void:
	if _pages.size() <= 1:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_dragging = true
			_drag_start_x = event.position.x
			_drag_start_offset = _pages_holder.position.x
		else:
			if not _dragging:
				return
			_dragging = false
			var diff: float = event.position.x - _drag_start_x
			var target := _current_page
			if diff < -SWIPE_THRESHOLD and _current_page < _pages.size() - 1:
				target = _current_page + 1
			elif diff > SWIPE_THRESHOLD and _current_page > 0:
				target = _current_page - 1
			_animate_to_page(target)
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _dragging:
			var diff: float = event.position.x - _drag_start_x
			var new_x := _drag_start_offset + diff
			var max_x: float = 0.0
			var min_x: float = -(float(_pages.size() - 1) * _screen_area.size.x)
			_pages_holder.position.x = clamp(new_x, min_x, max_x)

func _animate_to_page(page_idx: int) -> void:
	_current_page = page_idx
	var target_x := -page_idx * _screen_area.size.x
	var tween := create_tween()
	tween.tween_property(_pages_holder, "position:x", target_x, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_update_swipe_hints()
