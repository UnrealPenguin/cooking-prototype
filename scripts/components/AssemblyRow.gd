extends PanelContainer

var index: int = -1

@onready var _label: Label = %Label
@onready var _swatch: ColorRect = %Swatch

func setup(text: String, accent_color: Color = Color(0.8, 0.8, 0.8, 1)) -> void:
	if not is_node_ready():
		await ready
	_label.text = text
	_swatch.color = accent_color

func _get_drag_data(_at_position: Vector2):
	var preview := Label.new()
	preview.text = _label.text
	preview.add_theme_font_size_override("font_size", 14)
	preview.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	var bg := PanelContainer.new()
	bg.modulate = Color(1, 1, 1, 0.9)
	bg.add_child(preview)
	set_drag_preview(bg)
	return {"type": "assembly_row", "index": index}

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and str(data.get("type", "")) == "ingredient"

func _drop_data(_at_position: Vector2, data) -> void:
	var n: Node = get_parent()
	while n != null and not n.has_signal("ingredient_dropped"):
		n = n.get_parent()
	if n != null:
		n.emit_signal(
			"ingredient_dropped",
			str(data.get("ingredient", "")),
			str(data.get("state", "")),
		)
