extends PanelContainer
class_name OrderCard

signal expired(card: OrderCard)

var recipe_id: String = ""
var recipe: Dictionary = {}
var time_limit: float = 60.0
var time_left: float = 60.0
var active: bool = true

var _label: Label
var _components: Label
var _timer_bar: ProgressBar
var _bg: ColorRect

func setup(id: String, data: Dictionary) -> void:
	recipe_id = id
	recipe = data
	_label = get_node("Inner/Margin/VB/Label")
	_components = get_node("Inner/Margin/VB/Components")
	_timer_bar = get_node("Inner/Margin/VB/Timer")
	_bg = get_node("Inner/BG")
	time_limit = float(data.get("timer", 60.0))
	time_left = time_limit
	_label.text = str(data.get("label", id))
	_bg.color = DataLoader.parse_color(str(data.get("color", "#FFC107"))).darkened(0.3)
	_timer_bar.max_value = time_limit
	_timer_bar.value = time_limit
	var lines: Array[String] = []
	for comp in data.get("components", []):
		var ing_id: String = comp.get("ingredient", "")
		var ing: Dictionary = DataLoader.get_ingredient(ing_id)
		var state: String = comp.get("state", "prepped")
		var label_text: String = ing.get("label", ing_id)
		if state == "prepped":
			label_text = ing.get("prepped_label", label_text)
		elif state == "cooked":
			label_text = ing.get("cooked_label", label_text)
		lines.append("• " + label_text)
	_components.text = "\n".join(lines)

func _process(delta: float) -> void:
	if not active or _timer_bar == null:
		return
	time_left = max(0.0, time_left - delta)
	_timer_bar.value = time_left
	_timer_bar.modulate = _timer_color()
	if time_left <= 0.0:
		active = false
		emit_signal("expired", self)

func _timer_color() -> Color:
	var ratio: float = time_left / time_limit
	if ratio > 0.66:
		return Color(0.4, 0.9, 0.3)
	elif ratio > 0.33:
		return Color(1.0, 0.85, 0.2)
	else:
		return Color(1.0, 0.3, 0.2)

func stars_for_current_time() -> int:
	var ratio: float = time_left / time_limit
	if ratio > 0.66:
		return 3
	elif ratio > 0.33:
		return 2
	elif ratio > 0.0:
		return 1
	return 0

func coins_for_current_time() -> int:
	var base: int = int(recipe.get("base_coins", 10))
	var s: int = stars_for_current_time()
	match s:
		3: return base
		2: return int(base * 0.6)
		1: return int(base * 0.3)
		_: return 0

func stop() -> void:
	active = false
