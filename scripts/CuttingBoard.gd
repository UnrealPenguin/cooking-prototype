extends PanelContainer
class_name CuttingBoard

signal chopped(ingredient_id: String)
signal state_changed

enum State { EMPTY, CHOPPING, READY }

var state: int = State.EMPTY
var ingredient_id: String = ""
var ingredient: Dictionary = {}
var taps_remaining: int = 0
var _total_taps: int = 3
var can_collect_callable: Callable

var _label: Label
var _color_rect: ColorRect
var _sprite: TextureRect
var _progress: ProgressBar
var _status: Label
var _stage_textures: Array = []

func _ready() -> void:
	_label = get_node("Margin/VB/Label")
	_color_rect = get_node("Margin/VB/Color")
	_sprite = get_node("Margin/VB/Sprite")
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
	_load_stage_textures(id, ing)
	state = State.CHOPPING
	_render()
	emit_signal("state_changed")

# Loads chop-stage images: assets/ingredients/{icon}_chop0.png (whole) ...
# up to the last _chopN.png (fully chopped). Auto-detects how many exist.
func _load_stage_textures(id: String, ing: Dictionary) -> void:
	_stage_textures = []
	var base: String = str(ing.get("icon", id))
	var names: Array = [base, id]
	for tex_name in names:
		var i: int = 0
		while true:
			var path := "res://assets/ingredients/%s_chop%d.png" % [tex_name, i]
			if not ResourceLoader.exists(path):
				break
			_stage_textures.append(load(path))
			i += 1
		if not _stage_textures.is_empty():
			break

func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if state != State.CHOPPING:
		return
	taps_remaining -= 1
	_progress.value = float(_total_taps - taps_remaining)
	_status.text = "Tap to chop (%d)" % max(taps_remaining, 0)
	_update_stage()
	_pulse()
	if taps_remaining <= 0:
		_finish_chopping()

# Spreads the stage images evenly across the taps, so the count of images and
# the number of taps (prep_taps) can each be changed freely and the art scales
# to fit. Image 0 shows at placement, the last image lands one tap before the
# board collects. E.g. 5 taps / 3 images -> chop0, chop1 @tap2, chop2 @tap4.
func _update_stage() -> void:
	if _stage_textures.is_empty():
		_sprite.visible = false
		_color_rect.visible = true
		return
	var n: int = _stage_textures.size()
	var taps_done: int = _total_taps - taps_remaining
	var denom: int = max(_total_taps - 1, 1)
	var idx: int = int(floor(float(taps_done) * (n - 1) / float(denom)))
	idx = clamp(idx, 0, n - 1)
	_sprite.texture = _stage_textures[idx]
	_sprite.visible = true
	_color_rect.visible = false

func _finish_chopping() -> void:
	if can_collect_callable.is_valid() and not can_collect_callable.call(ingredient_id):
		state = State.READY
		_render_ready()
		emit_signal("state_changed")
		return
	var finished_id := ingredient_id
	_clear()
	emit_signal("chopped", finished_id)
	emit_signal("state_changed")

func try_collect() -> void:
	if state != State.READY:
		return
	if can_collect_callable.is_valid() and not can_collect_callable.call(ingredient_id):
		return
	var finished_id := ingredient_id
	_clear()
	emit_signal("chopped", finished_id)
	emit_signal("state_changed")

func discard_chopped() -> void:
	if state != State.READY:
		return
	_clear()
	emit_signal("state_changed")

func _get_drag_data(_at_position: Vector2):
	if state != State.READY:
		return null
	var label := Label.new()
	label.text = "%s ✓" % str(ingredient.get("prepped_label", ingredient.get("label", ingredient_id)))
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	var preview := PanelContainer.new()
	preview.modulate = Color(1, 1, 1, 0.9)
	preview.add_child(label)
	set_drag_preview(preview)
	return {"type": "board_chopped", "board": self}

func _clear() -> void:
	state = State.EMPTY
	ingredient_id = ""
	ingredient = {}
	taps_remaining = 0
	_stage_textures = []
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
	_update_stage()

func _render_empty() -> void:
	if _label == null:
		return
	_label.text = "- empty -"
	_color_rect.color = Color(0.2, 0.2, 0.2, 0.6)
	_color_rect.visible = true
	_sprite.visible = false
	_progress.max_value = 1.0
	_progress.value = 0.0
	_status.text = "Place an ingredient"

func _render_ready() -> void:
	if _label == null:
		return
	_label.text = "%s ✓" % str(ingredient.get("prepped_label", ingredient.get("label", ingredient_id)))
	_color_rect.color = DataLoader.parse_color(str(ingredient.get("color", "#CCCCCC"))).lightened(0.15)
	if not _stage_textures.is_empty():
		_sprite.texture = _stage_textures[_stage_textures.size() - 1]
		_sprite.visible = true
		_color_rect.visible = false
	else:
		_sprite.visible = false
		_color_rect.visible = true
	_progress.value = float(_total_taps)
	_status.text = "BOWL FULL - drag to trash"

func _pulse() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.06)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
