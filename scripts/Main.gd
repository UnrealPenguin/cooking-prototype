extends Control

const PrepItemScene := preload("res://scenes/PrepItem.tscn")
const ApplianceScene := preload("res://scenes/Appliance.tscn")
const OrderCardScene := preload("res://scenes/OrderCard.tscn")

@onready var _root: VBoxContainer = %Root
@onready var _assembly_view: AssemblyView = $AssemblyView
@onready var _level_complete: Control = %LevelComplete
@onready var _level_summary: Label = %Summary
@onready var _restart_btn: Button = %RestartBtn
@onready var _next_btn: Button = %NextBtn
@onready var _tutorial: Control = %Tutorial
@onready var _tutorial_start_btn: Button = %StartBtn

var _top_bar: HBoxContainer
var _level_title_label: Label
var _order_strip: HBoxContainer
var _stats_label: Label

var _screen_area: Control
var _pages_clip: Control
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

var _spawn_timer: float = 0.0
var _orders_spawned: int = 0
var _level_active: bool = false
var _next_level_id: int = 1

func _ready() -> void:
	_build_layout()
	_assembly_view.served.connect(_on_serve)
	_assembly_view.cancelled.connect(_on_assemble_cancel)
	_restart_btn.pressed.connect(_on_restart)
	_next_btn.pressed.connect(_on_next_level)
	_tutorial_start_btn.pressed.connect(_on_tutorial_dismiss)
	GameManager.level_started.connect(_on_level_started)
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.coins_changed.connect(func(_v): _update_stats())
	GameManager.stars_changed.connect(func(_v): _update_stats())
	get_viewport().size_changed.connect(_on_viewport_resized)
	# Defer start so autoloads finish loading
	call_deferred("_start_first_level")

func _start_first_level() -> void:
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
	_stats_label.text = "Coins: 0  Stars: 0"
	info_vb.add_child(_stats_label)

	_order_strip = HBoxContainer.new()
	_order_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_strip.add_theme_constant_override("separation", 8)
	_top_bar.add_child(_order_strip)

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

func _on_viewport_resized() -> void:
	_relayout_pages()

func _on_level_started(lvl: Dictionary) -> void:
	_level_active = true
	_orders_spawned = 0
	_spawn_timer = float(lvl.get("spawn_interval", 6.0)) - float(lvl.get("initial_delay", 1.0))
	_active_orders.clear()
	_ready_tray.clear()
	_level_title_label.text = str(lvl.get("name", "Shift"))
	_clear_children(_order_strip)
	_clear_children(_pages_holder)
	_clear_children(_ready_tray_box)
	_pages.clear()
	_appliances_ui.clear()
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
	var items := HBoxContainer.new()
	items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items.add_theme_constant_override("separation", 10)
	vb.add_child(items)
	for ing_id in lvl.get("prep_ingredients", []):
		var ing := DataLoader.get_ingredient(ing_id)
		if ing.is_empty():
			continue
		var prep := PrepItemScene.instantiate() as PrepItem
		items.add_child(prep)
		prep.setup(ing_id, ing)
		prep.prepped.connect(_on_prepped)
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
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 10)
	vb.add_child(items)
	for ing_id in lvl.get("prep_ingredients", []):
		var ing := DataLoader.get_ingredient(ing_id)
		if ing.is_empty():
			continue
		var prep := PrepItemScene.instantiate() as PrepItem
		items.add_child(prep)
		prep.setup(ing_id, ing)
		prep.prepped.connect(_on_prepped)

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

func _on_prepped(ingredient_id: String) -> void:
	_add_to_tray(ingredient_id, "prepped", 1)

func _on_cooked(ingredient_id: String) -> void:
	_add_to_tray(ingredient_id, "cooked", 1)

func _add_to_tray(ingredient_id: String, state: String, amount: int) -> void:
	var key := "%s:%s" % [ingredient_id, state]
	_ready_tray[key] = int(_ready_tray.get(key, 0)) + amount
	_refresh_ready_tray_ui()
	_refresh_order_assemble_buttons()

func _consume_from_tray(components: Array) -> void:
	var grouped := _group_components(components)
	for key in grouped.keys():
		_ready_tray[key] = max(0, int(_ready_tray.get(key, 0)) - int(grouped[key]))
		if int(_ready_tray[key]) == 0:
			_ready_tray.erase(key)
	_refresh_ready_tray_ui()
	_refresh_order_assemble_buttons()

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
	_stats_label.text = "Coins: %d  Stars: %d" % [GameManager.coins, GameManager.stars_total]

func _process(delta: float) -> void:
	if not _level_active:
		return
	if _orders_spawned < GameManager.total_orders():
		_spawn_timer += delta
		var interval := float(GameManager.current_level.get("spawn_interval", 6.0))
		var max_active := int(GameManager.current_level.get("max_simultaneous_orders", 1))
		if _spawn_timer >= interval and _active_orders.size() < max_active:
			_spawn_timer = 0.0
			_spawn_order()

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
	GameManager.record_order_result(false, 0, 0)

func _on_assemble_pressed(card: OrderCard) -> void:
	if not _tray_has_components(card.recipe.get("components", [])):
		return
	_assembly_view.open_for(card)

func _on_assemble_cancel() -> void:
	pass

func _on_serve(card: OrderCard) -> void:
	if card == null or not _active_orders.has(card):
		return
	var stars := card.stars_for_current_time()
	var coins := card.coins_for_current_time()
	_consume_from_tray(card.recipe.get("components", []))
	_active_orders.erase(card)
	card.stop()
	card.queue_free()
	GameManager.record_order_result(true, stars, coins)

func _on_level_completed(summary: Dictionary) -> void:
	_level_active = false
	_level_summary.text = "Completed: %d\nFailed: %d\nCoins: %d\nStars: %d" % [
		summary.get("completed", 0),
		summary.get("failed", 0),
		summary.get("coins", 0),
		summary.get("stars", 0)
	]
	var lvl_id := int(GameManager.current_level.get("id", 1))
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
