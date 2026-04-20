extends PanelContainer
class_name CuttingBoard

signal chopped(ingredient_id: String)
signal state_changed

enum State { EMPTY, CHOPPING }

var state: int = State.EMPTY
var ingredient_id: String = ""
var ingredient: Dictionary = {}
var taps_remaining: int = 0
var _total_taps: int = 3

var _label: Label
var _color_rect: ColorRect
var _progress: ProgressBar
var _status: Label

func _ready() -> void:
	_label = get_node("Margin/VB/Label")
	_color_rect = get_node("Margin/VB/Color")
	_progress = get_node("Margin/VB/Progress")
	_status = get_node("Margin/VB/Status")
	gui_input.connect(_on_gui_input)
	_render_empty()

func is_empty() -> bool:
	return state == State.EMPTY

func place(id: String, ing: Dictionary) -> void:
	if state != State.EMPTY:
		return
	ingredient_id = id
	ingredient = ing
	_total_taps = int(ing.get("prep_taps", 3))
	taps_remaining = _total_taps
	state = State.CHOPPING
	_render()
	emit_signal("state_changed")

func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if state != State.CHOPPING:
		return
	taps_remaining -= 1
	_progress.value = float(_total_taps - taps_remaining)
	_status.text = "Tap to chop (%d)" % max(taps_remaining, 0)
	_pulse()
	if taps_remaining <= 0:
		var finished_id := ingredient_id
		_clear()
		emit_signal("chopped", finished_id)
		emit_signal("state_changed")

func _clear() -> void:
	state = State.EMPTY
	ingredient_id = ""
	ingredient = {}
	taps_remaining = 0
	_render_empty()

func _render() -> void:
	if _label == null:
		return
	_label.text = "%s %s" % [
		ingredient.get("prep_verb", "Chop"),
		ingredient.get("label", ingredient_id)
	]
	_color_rect.color = DataLoader.parse_color(str(ingredient.get("color", "#CCCCCC")))
	_progress.max_value = float(_total_taps)
	_progress.value = 0.0
	_status.text = "Tap to chop (%d)" % taps_remaining

func _render_empty() -> void:
	if _label == null:
		return
	_label.text = "- empty -"
	_color_rect.color = Color(0.2, 0.2, 0.2, 0.6)
	_progress.max_value = 1.0
	_progress.value = 0.0
	_status.text = "Place an ingredient"

func _pulse() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.06)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
