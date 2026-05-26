extends PanelContainer

signal ingredient_dropped(ingredient_id: String, state: String)

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and str(data.get("type", "")) == "ingredient"

func _drop_data(_at_position: Vector2, data) -> void:
	var ing_id: String = str(data.get("ingredient", ""))
	var state: String = str(data.get("state", ""))
	if ing_id != "" and state != "":
		emit_signal("ingredient_dropped", ing_id, state)
