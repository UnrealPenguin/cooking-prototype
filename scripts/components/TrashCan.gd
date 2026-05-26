extends ColorRect

signal item_trashed(index: int)

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("type", "") == "assembly_row"

func _drop_data(_at_position: Vector2, data) -> void:
	emit_signal("item_trashed", int(data.get("index", -1)))
