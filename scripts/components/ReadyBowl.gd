extends Control

signal tapped(ingredient_id: String)

@onready var _bowl: TextureRect = %Bowl
@onready var _count_label: Label = %CountLabel

var ingredient_id: String = ""
var _capacity: int = 3
var _count: int = 0
var _empty_texture: Texture2D
var _full_texture: Texture2D

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	var tapped_now := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped_now = true
	elif event is InputEventScreenTouch and event.pressed:
		tapped_now = true
	if tapped_now and _count > 0:
		emit_signal("tapped", ingredient_id)

func setup(id: String, data: Dictionary, capacity: int = 3) -> void:
	ingredient_id = id
	_capacity = capacity
	if not is_node_ready():
		await ready
	if ResourceLoader.exists("res://assets/bowls/empty_bowl.png"):
		_empty_texture = load("res://assets/bowls/empty_bowl.png")
	var chopped_name: String = str(data.get("chopped_icon", data.get("icon", id)))
	var paths := [
		"res://assets/ingredients/%s_chopped.png" % chopped_name,
		"res://assets/ingredients/%s_chopped.png" % id,
		"res://assets/ingredients/%s_prepped.png" % chopped_name,
	]
	for p in paths:
		if ResourceLoader.exists(p):
			_full_texture = load(p)
			break
	tooltip_text = str(data.get("prepped_label", data.get("label", id)))
	set_count(0)

func set_count(n: int) -> void:
	_count = n
	if not is_node_ready():
		await ready
	if n > 0 and _full_texture != null:
		_bowl.texture = _full_texture
	else:
		_bowl.texture = _empty_texture
	_count_label.text = "%d/%d" % [n, _capacity]
