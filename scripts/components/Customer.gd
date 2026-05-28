extends Control

signal arrived_at_window
signal left_screen
signal tapped

const SPRITES := [
	"res://assets/customers/cat.png",
	"res://assets/customers/corgi.png",
	"res://assets/customers/fox.png",
	"res://assets/customers/raccoon.png",
]

const WALK_SPEED := 320.0  # pixels/second
const BOB_AMPLITUDE := 6.0
const BOB_PERIOD := 0.35

@onready var _sprite: TextureRect = %Sprite
@onready var _bubble: Control = %OrderBubble
@onready var _timer_bar: ProgressBar = %TimerBar

var _bob_time: float = 0.0
var _walking: bool = false
var _base_y: float = 0.0
var _arrived: bool = false
var _pending_order_text: String = ""
var _pending_order_color: Color = Color(1, 1, 1, 1)
var _has_pending_order: bool = false

func _ready() -> void:
	size = custom_minimum_size
	pivot_offset = size / 2.0
	_bubble.visible = false
	_timer_bar.visible = false
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if not _arrived:
		return
	var tapped_now: bool = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped_now = true
	elif event is InputEventScreenTouch and event.pressed:
		tapped_now = true
	if tapped_now:
		emit_signal("tapped")

func setup(sprite_path: String = "") -> void:
	if not is_node_ready():
		await ready
	var path := sprite_path
	if path == "" or not ResourceLoader.exists(path):
		path = SPRITES[randi() % SPRITES.size()]
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)

func walk_in(start_x: float, target_x: float, y: float) -> void:
	_base_y = y
	position = Vector2(start_x, y)
	_walking = true
	var distance: float = abs(target_x - start_x)
	var duration: float = distance / WALK_SPEED
	var tween := create_tween()
	tween.tween_property(self, "position:x", target_x, duration).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	_walking = false
	position.y = _base_y
	_arrived = true
	if _has_pending_order:
		_bubble.setup(_pending_order_text, _pending_order_color)
		_bubble.visible = true
	_timer_bar.visible = true
	emit_signal("arrived_at_window")

func show_order(text: String, accent_color: Color = Color(1, 1, 1, 1)) -> void:
	if not is_node_ready():
		await ready
	_pending_order_text = text
	_pending_order_color = accent_color
	_has_pending_order = true
	if _arrived:
		_bubble.setup(text, accent_color)
		_bubble.visible = true

func hide_order() -> void:
	if not is_node_ready():
		await ready
	_has_pending_order = false
	_bubble.visible = false

func set_time_ratio(ratio: float) -> void:
	if _timer_bar == null:
		return
	var clamped: float = clamp(ratio, 0.0, 1.0)
	_timer_bar.value = clamped
	if clamped > 0.66:
		_timer_bar.modulate = Color(0.4, 0.9, 0.3)
	elif clamped > 0.33:
		_timer_bar.modulate = Color(1.0, 0.85, 0.2)
	else:
		_timer_bar.modulate = Color(1.0, 0.3, 0.2)

func walk_off(exit_x: float) -> void:
	_bubble.visible = false
	_timer_bar.visible = false
	_walking = true
	var distance: float = abs(exit_x - position.x)
	var duration: float = distance / WALK_SPEED
	var tween := create_tween()
	tween.tween_property(self, "position:x", exit_x, duration).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	_walking = false
	emit_signal("left_screen")
	queue_free()

func _process(delta: float) -> void:
	if not _walking:
		return
	_bob_time += delta
	var bob := sin(_bob_time * TAU / BOB_PERIOD) * BOB_AMPLITUDE
	position.y = _base_y + bob
