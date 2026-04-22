extends Control

@onready var _play_btn: Button = %PlayBtn
@onready var _missions_btn: Button = %MissionsBtn
@onready var _settings_btn: Button = %SettingsBtn
@onready var _quit_btn: Button = %QuitBtn
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
	_play_btn.pressed.connect(_on_play)
	_missions_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Missions.tscn"))
	_settings_btn.pressed.connect(func(): _settings_panel.visible = true)
	_quit_btn.pressed.connect(func(): get_tree().quit())
	_close_settings_btn.pressed.connect(func(): _settings_panel.visible = false)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_clear_save_btn.pressed.connect(func(): _clear_save_confirm.popup_centered())
	_clear_save_confirm.confirmed.connect(func(): SaveManager.reset())
	GameManager.coins_changed.connect(func(v): _coins_label.text = "🪙 %d" % v)
	GameManager.gems_changed.connect(func(v): _gems_label.text = "💎 %d" % v)

	var bus_db: float = AudioServer.get_bus_volume_db(0)
	_volume_slider.value = clamp(db_to_linear(bus_db), 0.0, 1.0) * 100.0
	_on_volume_changed(_volume_slider.value)
	_fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_coins_label.text = "🪙 %d" % GameManager.coins
	_gems_label.text = "💎 %d" % GameManager.gems

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/Stages.tscn")

func _on_volume_changed(value: float) -> void:
	var linear: float = value / 100.0
	AudioServer.set_bus_volume_db(0, linear_to_db(max(linear, 0.0001)))
	_volume_value.text = "%d%%" % int(round(value))

func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
