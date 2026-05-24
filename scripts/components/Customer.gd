extends Control

signal arrived_at_window
signal left_screen

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

var _bob_time: float = 0.0
var _walking: bool = false
var _base_y: float = 0.0

func _ready() -> void:
	size = custom_minimum_size
	pivot_offset = size / 2.0

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
	emit_signal("arrived_at_window")

func walk_off(exit_x: float) -> void:
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
