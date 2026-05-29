extends ColorRect

signal item_trashed(index: int)
signal burnt_slot_trashed(slot: Object)
signal board_chopped_trashed(board: Object)

func _can_drop_data(_at_position: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var t: String = str(data.get("type", ""))
	return t == "assembly_row" or t == "burnt_slot" or t == "board_chopped"

func _drop_data(_at_position: Vector2, data) -> void:
	var t: String = str(data.get("type", ""))
	match t:
		"assembly_row":
			emit_signal("item_trashed", int(data.get("index", -1)))
		"burnt_slot":
			emit_signal("burnt_slot_trashed", data.get("slot"))
		"board_chopped":
			emit_signal("board_chopped_trashed", data.get("board"))
