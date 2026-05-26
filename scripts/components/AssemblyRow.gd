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
