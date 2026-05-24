extends Control

@onready var _icon: TextureRect = %Icon
@onready var _count_label: Label = %CountLabel

var ingredient_id: String = ""
var _texture: Texture2D
var _empty_texture: Texture2D

func setup(id: String, data: Dictionary) -> void:
	ingredient_id = id
	if not is_node_ready():
		await ready
	if ResourceLoader.exists("res://assets/bowls/empty_bowl.png"):
		_empty_texture = load("res://assets/bowls/empty_bowl.png")
	var icon_name: String = str(data.get("cooked_icon", data.get("icon", id)))
	var paths := [
		"res://assets/ingredients/%s_cooked.png" % icon_name,
		"res://assets/ingredients/%s_cooked.png" % id,
		"res://assets/ingredients/%s_toasted.png" % icon_name,
		"res://assets/ingredients/%s.png" % icon_name,
	]
	for p in paths:
		if ResourceLoader.exists(p):
			_texture = load(p)
			break
	tooltip_text = str(data.get("cooked_label", data.get("label", id)))
	set_count(0)

func set_count(n: int) -> void:
	if not is_node_ready():
		await ready
	if n > 0 and _texture != null:
		_icon.texture = _texture
	else:
		_icon.texture = _empty_texture
	_count_label.text = "%d" % n
	_count_label.visible = n > 0
