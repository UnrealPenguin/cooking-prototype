extends PanelContainer
class_name CookingSlot

signal cooked(ingredient_id: String)
signal burnt(ingredient_id: String)

enum State { EMPTY, COOKING, DONE, BURNT, CLEANING }

const BurnShader: Shader = preload("res://assets/shaders/burn_darken.gdshader")
# How charred the cooked sprite looks right before it burns. The shader ramps
# from 0 up to this over the ready window as a "about to burn" warning.
const READY_BURN_MAX: float = 1.0

var state: int = State.EMPTY
var ingredient_id: String = ""
var ingredient: Dictionary = {}
var can_collect_callable: Callable
var _cook_time: float = 0.0
var _grace_time: float = 0.0
var _cleaning_time: float = 0.0
var _timer: float = 0.0
var _collected: bool = false

var _label: Label
var _progress: ProgressBar
var _color_rect: ColorRect
var _sprite: TextureRect
var _status: Label
var _shader_mat: ShaderMaterial
var _raw_tex: Texture2D
var _cooked_tex: Texture2D
var _burnt_tex: Texture2D

func _ready() -> void:
	_label = get_node("Margin/VB/Label")
	_progress = get_node("Margin/VB/Progress")
	_color_rect = get_node("Margin/VB/Color")
	_sprite = get_node("Margin/VB/Sprite")
	_status = get_node("Margin/VB/Status")
	# Give each slot its own material so darkening one item doesn't affect others.
	# Only attached to the sprite while burnt (see _apply_visual).
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = BurnShader
	gui_input.connect(_on_gui_input)
	_render_empty()

func accepts(ing: Dictionary) -> bool:
	return state == State.EMPTY and bool(ing.get("needs_cook", false))

func place(id: String, ing: Dictionary, appliance: Dictionary) -> void:
	ingredient_id = id
	ingredient = ing
	_cook_time = float(ing.get("cook_time", 5.0))
	_grace_time = float(ing.get("done_grace", 3.0))
	_cleaning_time = float(appliance.get("cleaning_time", 2.0))
	_timer = 0.0
	_collected = false
	_load_textures(id, ing)
	state = State.COOKING
	_render()

# Loads the raw (cooking), cooked, and burnt sprites for this ingredient.
# A burnt sprite is mandatory: every cookable item must ship a {icon}_burnt.png
# so the burnt state is always hand-drawn and consistent.
func _load_textures(id: String, ing: Dictionary) -> void:
	_raw_tex = null
	_cooked_tex = null
	_burnt_tex = null
	var icon_name: String = str(ing.get("icon", id))
	var cooked_name: String = str(ing.get("cooked_icon", icon_name))
	var burnt_name: String = str(ing.get("burnt_icon", icon_name))
	_raw_tex = _first_existing([
		"res://assets/ingredients/%s_raw.png" % icon_name,
		"res://assets/ingredients/%s_raw.png" % id,
		"res://assets/ingredients/%s.png" % icon_name,
		"res://assets/ingredients/%s.png" % id,
	])
	_cooked_tex = _first_existing([
		"res://assets/ingredients/%s_cooked.png" % cooked_name,
		"res://assets/ingredients/%s_cooked.png" % id,
		"res://assets/ingredients/%s_toasted.png" % cooked_name,
	])
	_burnt_tex = _first_existing([
		"res://assets/ingredients/%s_burnt.png" % burnt_name,
		"res://assets/ingredients/%s_burnt.png" % id,
	])
	assert(_burnt_tex != null,
		"Missing burnt sprite for cookable ingredient '%s' - expected res://assets/ingredients/%s_burnt.png" % [id, burnt_name])
	if _raw_tex == null:
		_raw_tex = _cooked_tex
	if _cooked_tex == null:
		_cooked_tex = _raw_tex

func _first_existing(paths: Array) -> Texture2D:
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p)
	return null

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
			# Not picked up in time -> burns directly (no separate burning phase).
			if _timer >= _grace_time:
				state = State.BURNT
				_timer = 0.0
				emit_signal("burnt", ingredient_id)
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
			_apply_visual(_raw_tex, 0.0)
			_progress.max_value = _cook_time
			_progress.value = _timer
			_progress.modulate = Color(1, 1, 1)
			_status.text = "Cooking"
		State.DONE:
			_label.text = str(ingredient.get("cooked_label", "Done"))
			_color_rect.color = DataLoader.parse_color(str(ingredient.get("color", "#CCCCCC"))).lightened(0.15)
			# Gradually char the cooked sprite over the ready window as a warning
			# that it's about to burn if not collected.
			var ready_ratio: float = clamp(_timer / _grace_time, 0.0, 1.0) if _grace_time > 0.0 else 1.0
			_apply_visual(_cooked_tex, ready_ratio * READY_BURN_MAX)
			_progress.max_value = _grace_time
			_progress.value = _grace_time - _timer
			_progress.modulate = Color(1, 0.85, 0.2)
			_status.text = "READY - TAP!"
		State.BURNT:
			_label.text = "BURNT"
			_color_rect.color = Color(0.1, 0.1, 0.1)
			# Dedicated hand-drawn burnt sprite - no shader needed.
			_apply_visual(_burnt_tex, 0.0)
			_progress.value = 0.0
			_status.text = "DRAG TO TRASH"
		State.CLEANING:
			_label.text = "Cleaning..."
			_color_rect.color = Color(0.4, 0.4, 0.4)
			_apply_visual(null, 0.0)
			_progress.max_value = _cleaning_time
			_progress.value = _timer
			_progress.modulate = Color(0.6, 0.8, 1.0)
			_status.text = "Cleaning"

# Shows the sprite with the given darken amount (0..1), or falls back to the
# ColorRect when no texture is available for this ingredient. The darken shader
# is only attached when actually darkening, so cooking/done items render with no
# material at all (guaranteeing no filter until the item is burnt).
func _apply_visual(tex: Texture2D, darken: float) -> void:
	if tex == null:
		_sprite.visible = false
		_color_rect.visible = true
		return
	_sprite.texture = tex
	if darken > 0.0:
		_shader_mat.set_shader_parameter("burn_amount", darken)
		_sprite.material = _shader_mat
	else:
		_sprite.material = null
	_sprite.visible = true
	_color_rect.visible = false

func _render_empty() -> void:
	_label.text = "- empty -"
	_color_rect.color = Color(0.2, 0.2, 0.2, 0.6)
	_color_rect.visible = true
	if _sprite != null:
		_sprite.visible = false
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
		if can_collect_callable.is_valid() and not can_collect_callable.call(ingredient_id):
			return
		_collected = true
		emit_signal("cooked", ingredient_id)
		state = State.EMPTY
		ingredient_id = ""
		ingredient = {}
		_timer = 0.0
		_render()

func _get_drag_data(_at_position: Vector2):
	if state != State.BURNT:
		return null
	var preview := Label.new()
	preview.text = "BURNT"
	preview.add_theme_font_size_override("font_size", 14)
	preview.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	var bg := PanelContainer.new()
	bg.modulate = Color(0.9, 0.3, 0.1, 0.9)
	bg.add_child(preview)
	set_drag_preview(bg)
	return {"type": "burnt_slot", "slot": self}

func discard_burnt() -> void:
	if state != State.BURNT:
		return
	state = State.CLEANING
	_timer = 0.0
	_render()
