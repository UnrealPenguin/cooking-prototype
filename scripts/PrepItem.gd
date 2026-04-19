extends PanelContainer
class_name PrepItem

signal prepped(ingredient_id: String)

var ingredient_id: String = ""
var ingredient: Dictionary = {}
var taps_remaining: int = 0
var _in_progress: bool = false

var _label: Label
var _progress: ProgressBar
var _color_rect: ColorRect

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func setup(id: String, data: Dictionary) -> void:
	ingredient_id = id
	ingredient = data
	_label = get_node("Margin/VB/Label")
	_progress = get_node("Margin/VB/Progress")
	_color_rect = get_node("Margin/VB/Color")
	taps_remaining = int(data.get("prep_taps", 3))
	_label.text = "%s %s" % [data.get("prep_verb", "Prep"), data.get("label", id)]
	_color_rect.color = DataLoader.parse_color(str(data.get("color", "#CCCCCC")))
	_progress.max_value = float(data.get("prep_taps", 3))
	_progress.value = 0.0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap()
	elif event is InputEventScreenTouch and event.pressed:
		_tap()

func _tap() -> void:
	if _in_progress:
		return
	taps_remaining -= 1
	var total: float = float(ingredient.get("prep_taps", 3))
	_progress.value = total - float(taps_remaining)
	_pulse()
	if taps_remaining <= 0:
		_in_progress = true
		emit_signal("prepped", ingredient_id)
		_reset()

func _reset() -> void:
	taps_remaining = int(ingredient.get("prep_taps", 3))
	_progress.value = 0.0
	_in_progress = false

func _pulse() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.06)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
