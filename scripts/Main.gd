extends Control

const CuttingBoardScene := preload("res://scenes/CuttingBoard.tscn")
const ApplianceScene := preload("res://scenes/Appliance.tscn")
const OrderCardScene := preload("res://scenes/OrderCard.tscn")
const RawIngredientButtonScene := preload("res://scenes/components/RawIngredientButton.tscn")
const ReadyBowlScene := preload("res://scenes/components/ReadyBowl.tscn")
const CookedItemScene := preload("res://scenes/components/CookedItem.tscn")
const CustomerScene := preload("res://scenes/components/Customer.tscn")
const AssemblyRowScene := preload("res://scenes/components/AssemblyRow.tscn")

const CUSTOMER_QUEUE_SLOTS := 3
const CUSTOMER_OFFSCREEN_MARGIN := 200.0

const CONTAINER_CAPACITY := 3

@onready var _root: VBoxContainer = %Root
@onready var _crate_slots: Array[Control] = [
	%CrateSlot1, %CrateSlot2, %CrateSlot3, %CrateSlot4, %CrateSlot5,
]
@onready var _bowl_slots: Array[Control] = [
	%BowlSlot1, %BowlSlot2, %BowlSlot3, %BowlSlot4, %BowlSlot5,
]
@onready var _cutting_board_slot: Control = %CuttingBoardSlot
@onready var _cook_raw_slots: Array[Control] = [
	%CookRawSlot1, %CookRawSlot2, %CookRawSlot3, %CookRawSlot4, %CookRawSlot5,
]
@onready var _appliance_slots: Array[Control] = [
	%ApplianceSlot1, %ApplianceSlot2, %ApplianceSlot3, %ApplianceSlot4,
]
@onready var _cooked_slots: Array[Control] = [
	%CookedSlot1, %CookedSlot2, %CookedSlot3,
]
@onready var _customers_layer: Control = %CustomersLayer
@onready var _window_left: Control = %WindowLeft
@onready var _window_right: Control = %WindowRight
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
@onready var _pause_btn_scene: TextureButton = %PauseBtn
@onready var _assembly_panel: PanelContainer = %AssemblyPanel
@onready var _assembly_rows: Container = %AssemblyRows
@onready var _trash_can: ColorRect = %TrashCan

var _top_bar: HBoxContainer
var _level_title_label: Label
var _order_strip: HBoxContainer
var _stats_label: Label

var _active_orders: Array[OrderCard] = []
var _ready_tray: Dictionary = {}  # "ing:state" -> int count
var _appliances_ui: Array[Appliance] = []
var _cutting_board: Node
var _raw_buttons: Dictionary = {}  # ingredient_id -> Button (cutting-board raws)
var _ready_bowls: Dictionary = {}  # ingredient_id -> ReadyBowl
var _cook_raw_buttons: Dictionary = {}  # ingredient_id -> Button (place-on-appliance raws)
var _cooked_items: Dictionary = {}  # ingredient_id -> CookedItem
var _assembly: Array[Dictionary] = []  # [{ingredient, state}, ...]
var _customers_by_card: Dictionary = {}  # OrderCard -> Customer
var _occupied_window_xs: Array[float] = []
const MAX_PREP_SLOTS := 5

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
	_hide_slot_placeholders()
	_build_layout()
	_restart_btn.pressed.connect(_on_restart)
	_next_btn.pressed.connect(_on_next_level)
	_home_btn.pressed.connect(_on_quit_to_home)
	_tutorial_start_btn.pressed.connect(_on_tutorial_dismiss)
	_resume_btn.pressed.connect(_on_resume)
	_pause_btn_scene.pressed.connect(_on_pause)
	if _trash_can != null and _trash_can.has_signal("item_trashed"):
		_trash_can.item_trashed.connect(_clear_assembly)
	if _trash_can != null and _trash_can.has_signal("burnt_slot_trashed"):
		_trash_can.burnt_slot_trashed.connect(_on_burnt_slot_trashed)
	if _assembly_panel != null and _assembly_panel.has_signal("ingredient_dropped"):
		_assembly_panel.ingredient_dropped.connect(_on_ingredient_dropped)
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
	# Defer start so autoloads finish loading
	call_deferred("_start_first_level")

func _start_first_level() -> void:
	_next_level_id = GameManager.pending_level_id
	GameManager.start_level(_next_level_id)

func _build_layout() -> void:
	# Top bar
	_top_bar = HBoxContainer.new()
	_top_bar.custom_minimum_size = Vector2(0, 150)
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

	_prep_label = Label.new()
	_prep_label.visible = false
	_prep_label.add_theme_font_size_override("font_size", 14)
	_prep_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	info_vb.add_child(_prep_label)

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
	_assembly.clear()
	_refresh_assembly_ui()
	_occupied_window_xs.clear()
	if _customers_layer != null:
		for child in _customers_layer.get_children():
			if child == _window_left or child == _window_right:
				continue
			child.queue_free()
	_customers_by_card.clear()
	_level_title_label.text = str(lvl.get("name", "Shift"))
	_clear_children(_order_strip)
	_appliances_ui.clear()
	_cutting_board = null
	_raw_buttons.clear()
	_ready_bowls.clear()
	_cook_raw_buttons.clear()
	_cooked_items.clear()
	_update_stats()

	_build_prep_section(lvl)
	_build_cook_section(lvl)
	_refresh_prep_ui()

	if bool(lvl.get("show_swipe_tutorial", false)):
		_tutorial.visible = true

func _cookable_ingredient_ids_for_appliances(appliance_ids: Array) -> Array:
	var out: Array = []
	for id in DataLoader.ingredients.keys():
		var ing: Dictionary = DataLoader.ingredients[id]
		if bool(ing.get("needs_cook", false)) and ing.get("appliance", "") in appliance_ids:
			out.append(id)
	return out

func _place_on_appliance(ingredient_id: String) -> void:
	var ing := DataLoader.get_ingredient(ingredient_id)
	var needs_prep: bool = bool(ing.get("needs_prep", false))
	if needs_prep and _container_count(ingredient_id) <= 0:
		return
	for app in _appliances_ui:
		if app.try_place(ingredient_id, ing):
			if needs_prep:
				_consume_from_tray([{"ingredient": ingredient_id, "state": "prepped"}])
			return

func _build_cook_section(lvl: Dictionary) -> void:
	for slot in _cook_raw_slots:
		_clear_children(slot)
	for slot in _appliance_slots:
		_clear_children(slot)
	for slot in _cooked_slots:
		_clear_children(slot)
	var appliance_ids: Array = lvl.get("appliances", [])
	_build_cook_raw_row(appliance_ids)
	for i in appliance_ids.size():
		if i >= _appliance_slots.size():
			break
		var app_id: String = appliance_ids[i]
		var app_data := DataLoader.get_appliance(app_id)
		if app_data.is_empty():
			continue
		var app := ApplianceScene.instantiate() as Appliance
		_appliance_slots[i].add_child(app)
		app.set_anchors_preset(Control.PRESET_FULL_RECT)
		app.setup(app_id, app_data)
		app.item_cooked.connect(_on_cooked)
		app.item_burnt.connect(_on_burnt)
		_appliances_ui.append(app)

func _build_cook_raw_row(appliance_ids: Array) -> void:
	var cookable_ids := _cookable_ingredient_ids_for_appliances(appliance_ids)
	for i in cookable_ids.size():
		if i >= _cook_raw_slots.size():
			break
		var id: String = cookable_ids[i]
		var ing := DataLoader.get_ingredient(id)
		var btn := RawIngredientButtonScene.instantiate()
		_cook_raw_slots[i].add_child(btn)
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.setup(id, ing)
		btn.tapped.connect(_place_on_appliance)
		if bool(ing.get("needs_prep", false)):
			_cook_raw_buttons[id] = btn

		if i < _cooked_slots.size():
			var cooked := CookedItemScene.instantiate()
			_cooked_slots[i].add_child(cooked)
			cooked.set_anchors_preset(Control.PRESET_FULL_RECT)
			cooked.setup(id, ing)
			_cooked_items[id] = cooked

func _build_prep_section(lvl: Dictionary) -> void:
	for slot in _crate_slots:
		_clear_children(slot)
	for slot in _bowl_slots:
		_clear_children(slot)
	_clear_children(_cutting_board_slot)

	var prep_ids: Array = []
	for ing_id in lvl.get("prep_ingredients", []):
		if prep_ids.size() >= MAX_PREP_SLOTS:
			break
		prep_ids.append(str(ing_id))

	for i in prep_ids.size():
		var id: String = prep_ids[i]
		var ing := DataLoader.get_ingredient(id)
		if ing.is_empty():
			continue
		var btn := RawIngredientButtonScene.instantiate()
		_crate_slots[i].add_child(btn)
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.setup(id, ing)
		btn.tapped.connect(_on_raw_pressed)
		_raw_buttons[id] = btn

		var bowl := ReadyBowlScene.instantiate()
		_bowl_slots[i].add_child(bowl)
		bowl.set_anchors_preset(Control.PRESET_FULL_RECT)
		bowl.setup(id, ing, CONTAINER_CAPACITY)
		_ready_bowls[id] = bowl

	_cutting_board = CuttingBoardScene.instantiate()
	_cutting_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cutting_board_slot.add_child(_cutting_board)
	_cutting_board.chopped.connect(_on_chopped)
	_cutting_board.state_changed.connect(_refresh_prep_ui)

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
	for id in _ready_bowls.keys():
		var bowl = _ready_bowls[id]
		bowl.set_count(_container_count(id))
	for id in _cook_raw_buttons.keys():
		var btn: Button = _cook_raw_buttons[id]
		btn.disabled = _container_count(id) <= 0

func _add_to_tray(ingredient_id: String, state: String, amount: int) -> void:
	var key := "%s:%s" % [ingredient_id, state]
	_ready_tray[key] = int(_ready_tray.get(key, 0)) + amount
	_refresh_cooked_ui()
	_refresh_prep_ui()

func _consume_from_tray(components: Array) -> void:
	var grouped := _group_components(components)
	for key in grouped.keys():
		_ready_tray[key] = max(0, int(_ready_tray.get(key, 0)) - int(grouped[key]))
		if int(_ready_tray[key]) == 0:
			_ready_tray.erase(key)
	_refresh_cooked_ui()
	_refresh_prep_ui()

func _refresh_cooked_ui() -> void:
	for id in _cooked_items.keys():
		var item = _cooked_items[id]
		item.set_count(int(_ready_tray.get("%s:cooked" % id, 0)))

func _group_components(components: Array) -> Dictionary:
	var out: Dictionary = {}
	for comp in components:
		var key := "%s:%s" % [comp.get("ingredient", ""), comp.get("state", "")]
		out[key] = int(out.get(key, 0)) + 1
	return out

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
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event): _on_order_card_input(card, event))
	_active_orders.append(card)
	_orders_spawned += 1
	_spawn_customer_for(card)

func _on_order_expired(card: OrderCard) -> void:
	if not _active_orders.has(card):
		return
	_active_orders.erase(card)
	card.queue_free()
	_stage_angry = true
	GameManager.record_order_result(false)
	_dismiss_customer_for(card)

func _on_serve(card: OrderCard) -> void:
	if card == null or not _active_orders.has(card):
		return
	var coins := card.coins_for_current_time()
	var ratio: float = card.time_left / card.time_limit if card.time_limit > 0.0 else 0.0
	if ratio < 0.33:
		_stage_angry = true
	_stage_coins += coins
	GameManager.add_coins(coins)
	MissionManager.track_coins_earned(coins)
	_update_stats()
	_assembly.clear()
	_refresh_assembly_ui()
	_active_orders.erase(card)
	card.stop()
	card.queue_free()
	GameManager.record_order_result(true)
	_dismiss_customer_for(card)

func _on_burnt(_ingredient_id: String) -> void:
	_stage_burnt = true

func _on_order_card_input(card: OrderCard, event: InputEvent) -> void:
	var tapped: bool = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	elif event is InputEventScreenTouch and event.pressed:
		tapped = true
	if not tapped:
		return
	if _assembly_matches_recipe(card.recipe):
		_on_serve(card)

func _on_ingredient_dropped(ing_id: String, state: String) -> void:
	if _assembly_contains(ing_id, state):
		return
	if not _can_add_to_assembly(ing_id, state):
		return
	var key := "%s:%s" % [ing_id, state]
	if int(_ready_tray.get(key, 0)) <= 0:
		return
	_ready_tray[key] = int(_ready_tray[key]) - 1
	if int(_ready_tray[key]) == 0:
		_ready_tray.erase(key)
	_push_to_assembly({"ingredient": ing_id, "state": state})
	if state == "prepped":
		_refresh_prep_ui()
	else:
		_refresh_cooked_ui()

func _assembly_contains(ing_id: String, state: String) -> bool:
	for comp in _assembly:
		if str(comp.get("ingredient", "")) == ing_id and str(comp.get("state", "")) == state:
			return true
	return false

func _can_add_to_assembly(ingredient_id: String, state: String) -> bool:
	var candidate := {"ingredient": ingredient_id, "state": state}
	var proposed: Array = _assembly.duplicate()
	proposed.append(candidate)
	var proposed_group: Dictionary = _group_components(proposed)
	for recipe_id in DataLoader.recipes:
		var recipe: Dictionary = DataLoader.recipes[recipe_id]
		var recipe_group: Dictionary = _group_components(recipe.get("components", []))
		var fits := true
		for key in proposed_group.keys():
			if int(proposed_group[key]) > int(recipe_group.get(key, 0)):
				fits = false
				break
		if fits:
			return true
	return false

func _push_to_assembly(comp: Dictionary) -> void:
	_assembly.append(comp)
	_refresh_assembly_ui()

func _clear_assembly(_idx: int = -1) -> void:
	_assembly.clear()
	_refresh_assembly_ui()

func _on_burnt_slot_trashed(slot) -> void:
	if slot != null and is_instance_valid(slot) and slot.has_method("discard_burnt"):
		slot.discard_burnt()

func _hide_slot_placeholders() -> void:
	var slots: Array = []
	slots.append_array(_crate_slots)
	slots.append_array(_bowl_slots)
	slots.append_array(_cooked_slots)
	slots.append_array(_cook_raw_slots)
	slots.append_array(_appliance_slots)
	if _cutting_board_slot != null:
		slots.append(_cutting_board_slot)
	for slot in slots:
		if slot == null:
			continue
		var p: Node = slot.get_node_or_null("Placeholder")
		if p != null and p is CanvasItem:
			(p as CanvasItem).visible = false

func _assembly_matches_recipe(recipe: Dictionary) -> bool:
	var required := _group_components(recipe.get("components", []))
	var have := _group_components(_assembly)
	if required.size() != have.size():
		return false
	for key in required.keys():
		if int(have.get(key, 0)) != int(required[key]):
			return false
	return true

func _refresh_assembly_ui() -> void:
	if _assembly_rows == null:
		return
	_clear_children(_assembly_rows)
	for i in _assembly.size():
		var comp: Dictionary = _assembly[i]
		var row := AssemblyRowScene.instantiate()
		row.index = i
		row.set_meta("comp", comp)
		var ing := DataLoader.get_ingredient(str(comp.get("ingredient", "")))
		var state: String = str(comp.get("state", "prepped"))
		var text: String = ing.get("label", comp.get("ingredient", ""))
		if state == "prepped":
			text = ing.get("prepped_label", text)
		elif state == "cooked":
			text = ing.get("cooked_label", text)
		_assembly_rows.add_child(row)
		row.setup(text, DataLoader.parse_color(str(ing.get("color", "#CCCCCC"))))

func _spawn_customer_for(card: OrderCard) -> void:
	if _customers_layer == null or _window_left == null or _window_right == null:
		return
	var customer := CustomerScene.instantiate()
	_customers_layer.add_child(customer)
	customer.setup()
	var color := DataLoader.parse_color(str(card.recipe.get("color", "#FFC107")))
	customer.show_order(_format_recipe_ingredients(card.recipe), color)
	var target_x := _next_window_x()
	_occupied_window_xs.append(target_x)
	_customers_by_card[card] = customer
	customer.tapped.connect(func(): _on_customer_tapped(card))
	var start_x: float = _customers_layer.size.x + CUSTOMER_OFFSCREEN_MARGIN
	customer.walk_in(start_x, target_x, _window_left.position.y)

func _on_customer_tapped(card: OrderCard) -> void:
	if not _active_orders.has(card):
		return
	if _assembly_matches_recipe(card.recipe):
		_on_serve(card)

func _dismiss_customer_for(card: OrderCard) -> void:
	if not _customers_by_card.has(card):
		return
	var customer = _customers_by_card[card]
	_customers_by_card.erase(card)
	if customer == null or not is_instance_valid(customer):
		return
	var target_x: float = customer.position.x
	_occupied_window_xs.erase(target_x)
	customer.walk_off(-CUSTOMER_OFFSCREEN_MARGIN)

func _format_recipe_ingredients(recipe: Dictionary) -> String:
	var names: Array[String] = []
	for comp in recipe.get("components", []):
		var ing_id: String = comp.get("ingredient", "")
		var ing: Dictionary = DataLoader.get_ingredient(ing_id)
		names.append(str(ing.get("label", ing_id)))
	return " + ".join(names)

func _next_window_x() -> float:
	var x_min: float = _window_left.position.x
	var x_max: float = _window_right.position.x
	var step: float = (x_max - x_min) / float(CUSTOMER_QUEUE_SLOTS - 1)
	for i in CUSTOMER_QUEUE_SLOTS:
		var x: float = x_min + step * float(i)
		if not _occupied_window_xs.has(x):
			return x
	return x_min

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
	get_tree().change_scene_to_file("res://scenes/Stages.tscn")

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
