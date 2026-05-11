extends Control

@onready var _bowl: TextureRect = %Bowl
@onready var _content: TextureRect = %Content
@onready var _count_label: Label = %CountLabel

var ingredient_id: String = ""
var _capacity: int = 3
var _count: int = 0

func setup(id: String, data: Dictionary, capacity: int = 3) -> void:
	ingredient_id = id
	_capacity = capacity
	if not is_node_ready():
		await ready
	if ResourceLoader.exists("res://assets/bowls/empty_bowl.png"):
		_bowl.texture = load("res://assets/bowls/empty_bowl.png")
	var chopped_name: String = str(data.get("chopped_icon", data.get("icon", id)))
	var paths := [
		"res://assets/ingredients/%s_chopped.png" % chopped_name,
		"res://assets/ingredients/%s_chopped.png" % id,
		"res://assets/ingredients/%s_prepped.png" % chopped_name,
	]
	for p in paths:
		if ResourceLoader.exists(p):
			_content.texture = load(p)
			break
	tooltip_text = str(data.get("prepped_label", data.get("label", id)))
	set_count(0)

func set_count(n: int) -> void:
	_count = n
	if not is_node_ready():
		await ready
	_content.visible = _content.texture != null and n > 0
	_count_label.text = "%d/%d" % [n, _capacity]
