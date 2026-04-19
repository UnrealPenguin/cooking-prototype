extends Control

@onready var _level_grid: GridContainer = %LevelGrid
@onready var _settings_btn: Button = %SettingsBtn
@onready var _settings_panel: Control = %SettingsPanel
@onready var _close_settings_btn: Button = %CloseSettingsBtn
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _volume_value: Label = %VolumeValue
@onready var _fullscreen_check: CheckBox = %FullscreenCheck
@onready var _coins_label: Label = %CoinsLabel
@onready var _gems_label: Label = %GemsLabel
@onready var _clear_save_btn: Button = %ClearSaveBtn
@onready var _clear_save_confirm: ConfirmationDialog = %ClearSaveConfirm

func _ready() -> void:
	_settings_btn.pressed.connect(func(): _settings_panel.visible = true)
	_close_settings_btn.pressed.connect(func(): _settings_panel.visible = false)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_clear_save_btn.pressed.connect(func(): _clear_save_confirm.popup_centered())
	_clear_save_confirm.confirmed.connect(_on_clear_save)
	GameManager.coins_changed.connect(func(v): _coins_label.text = "🪙 %d" % v)
	GameManager.gems_changed.connect(func(v): _gems_label.text = "💎 %d" % v)
	_coins_label.text = "🪙 %d" % GameManager.coins
	_gems_label.text = "💎 %d" % GameManager.gems

	var bus_db: float = AudioServer.get_bus_volume_db(0)
	_volume_slider.value = clamp(db_to_linear(bus_db), 0.0, 1.0) * 100.0
	_on_volume_changed(_volume_slider.value)
	_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

	call_deferred("_build_levels")

func _build_levels() -> void:
	for child in _level_grid.get_children():
		child.queue_free()
	for lvl in DataLoader.levels:
		var id: int = int(lvl.get("id", 1))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 110)
		btn.text = "%s\n\n%s" % [str(lvl.get("name", "Shift %d" % id)), _level_blurb(lvl)]
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func(): _start_level(id))
		_level_grid.add_child(btn)

func _level_blurb(lvl: Dictionary) -> String:
	var orders: int = int(lvl.get("total_orders", 0))
	var mode: String = str(lvl.get("screen_mode", "single"))
	return "%d orders · %s screen" % [orders, mode]

func _start_level(id: int) -> void:
	GameManager.pending_level_id = id
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_volume_changed(value: float) -> void:
	var linear: float = value / 100.0
	AudioServer.set_bus_volume_db(0, linear_to_db(max(linear, 0.0001)))
	_volume_value.text = "%d%%" % int(round(value))

func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func _on_clear_save() -> void:
	SaveManager.reset()
