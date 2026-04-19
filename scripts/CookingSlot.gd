extends PanelContainer
class_name CookingSlot

signal cooked(ingredient_id: String)

enum State { EMPTY, COOKING, DONE, BURNING, BURNT, CLEANING }

var state: int = State.EMPTY
var ingredient_id: String = ""
var ingredient: Dictionary = {}
var _cook_time: float = 0.0
var _grace_time: float = 0.0
var _burn_time: float = 0.0
var _cleaning_time: float = 0.0
var _timer: float = 0.0
var _collected: bool = false

var _label: Label
var _progress: ProgressBar
var _color_rect: ColorRect
var _status: Label

func _ready() -> void:
	_label = get_node("Margin/VB/Label")
	_progress = get_node("Margin/VB/Progress")
	_color_rect = get_node("Margin/VB/Color")
	_status = get_node("Margin/VB/Status")
	gui_input.connect(_on_gui_input)
	_render_empty()

func accepts(ing: Dictionary) -> bool:
	return state == State.EMPTY and bool(ing.get("needs_cook", false))

func place(id: String, ing: Dictionary, appliance: Dictionary) -> void:
	ingredient_id = id
	ingredient = ing
	_cook_time = float(ing.get("cook_time", 5.0))
	_grace_time = float(ing.get("done_grace", 3.0))
	_burn_time = float(ing.get("burn_time", 3.0))
	_cleaning_time = float(appliance.get("cleaning_time", 2.0))
	_timer = 0.0
	_collected = false
	state = State.COOKING
	_render()

func _process(delta: float) -> void:
	if _label == null:
		return
	if state == State.EMPTY or state == State.BURNT:
		return
	_timer += delta
	match state:
		State.COOKING:
			if _timer >= _cook_time:
				state = State.DONE
				_timer = 0.0
		State.DONE:
			if _timer >= _grace_time:
				state = State.BURNING
				_timer = 0.0
		State.BURNING:
			if _timer >= _burn_time:
				state = State.BURNT
				_timer = 0.0
		State.CLEANING:
			if _timer >= _cleaning_time:
				state = State.EMPTY
				ingredient_id = ""
				ingredient = {}
				_timer = 0.0
	_render()

func _render() -> void:
	if _label == null:
		return
	match state:
		State.EMPTY:
			_render_empty()
		State.COOKING:
			_label.text = str(ingredient.get("label", ingredient_id))
			_color_rect.color = DataLoader.parse_color(str(ingredient.get("color", "#CCCCCC")))
			_progress.max_value = _cook_time
			_progress.value = _timer
			_progress.modulate = Color(1, 1, 1)
			_status.text = "Cooking"
		State.DONE:
			_label.text = str(ingredient.get("cooked_label", "Done"))
			_color_rect.color = DataLoader.parse_color(str(ingredient.get("color", "#CCCCCC"))).lightened(0.15)
			_progress.max_value = _grace_time
			_progress.value = _grace_time - _timer
			_progress.modulate = Color(1, 0.85, 0.2)
			_status.text = "READY - TAP!"
		State.BURNING:
			_label.text = "%s!" % str(ingredient.get("cooked_label", "Done"))
			_color_rect.color = Color(0.9, 0.3, 0.1)
			_progress.max_value = _burn_time
			_progress.value = _burn_time - _timer
			_progress.modulate = Color(1, 0.2, 0.2)
			_status.text = "BURNING!"
		State.BURNT:
			_label.text = "BURNT"
			_color_rect.color = Color(0.1, 0.1, 0.1)
			_progress.value = 0.0
			_status.text = "TAP TO DISCARD"
		State.CLEANING:
			_label.text = "Cleaning..."
			_color_rect.color = Color(0.4, 0.4, 0.4)
			_progress.max_value = _cleaning_time
			_progress.value = _timer
			_progress.modulate = Color(0.6, 0.8, 1.0)
			_status.text = "Cleaning"

func _render_empty() -> void:
	_label.text = "- empty -"
	_color_rect.color = Color(0.2, 0.2, 0.2, 0.6)
	_progress.value = 0.0
	_status.text = ""

func _on_gui_input(event: InputEvent) -> void:
	var tapped: bool = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	elif event is InputEventScreenTouch and event.pressed:
		tapped = true
	if not tapped:
		return
	if state == State.DONE and not _collected:
		_collected = true
		emit_signal("cooked", ingredient_id)
		state = State.EMPTY
		ingredient_id = ""
		ingredient = {}
		_timer = 0.0
		_render()
	elif state == State.BURNT:
		state = State.CLEANING
		_timer = 0.0
		_render()
