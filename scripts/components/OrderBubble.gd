extends Control

@onready var _label: Label = %Label

func setup(text: String, _accent_color: Color = Color(1, 1, 1, 1)) -> void:
	if not is_node_ready():
		await ready
	_label.text = text
