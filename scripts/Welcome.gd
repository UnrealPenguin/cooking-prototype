extends Control

@onready var _prompt: Label = %Prompt

var _advancing: bool = false

func _ready() -> void:
	_animate_prompt()

func _animate_prompt() -> void:
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(_prompt, "modulate:a", 0.25, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_prompt, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if _advancing:
		return
	var trigger: bool = false
	if event is InputEventMouseButton and event.pressed:
		trigger = true
	elif event is InputEventScreenTouch and event.pressed:
		trigger = true
	elif event is InputEventKey and event.pressed and not event.echo:
		trigger = true
	if trigger:
		_advance()

func _advance() -> void:
	_advancing = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/Home.tscn"))
