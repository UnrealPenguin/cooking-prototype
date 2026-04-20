extends PanelContainer
class_name Appliance

signal item_cooked(ingredient_id: String)
signal item_burnt(ingredient_id: String)

var appliance_id: String = ""
var appliance_data: Dictionary = {}
var _slots: Array[CookingSlot] = []
var _cooking_slot_scene: PackedScene = preload("res://scenes/CookingSlot.tscn")

var _title: Label
var _slots_box: HBoxContainer
var _bg: ColorRect

func setup(id: String, data: Dictionary) -> void:
	appliance_id = id
	appliance_data = data
	_title = get_node("Inner/Margin/VB/Title")
	_slots_box = get_node("Inner/Margin/VB/Slots")
	_bg = get_node("Inner/BG")
	_title.text = str(data.get("label", id)).to_upper()
	_bg.color = DataLoader.parse_color(str(data.get("color", "#555555")))
	for child in _slots_box.get_children():
		child.queue_free()
	_slots.clear()
	var n: int = int(data.get("slots", 1))
	for i in n:
		var slot: CookingSlot = _cooking_slot_scene.instantiate() as CookingSlot
		_slots_box.add_child(slot)
		slot.cooked.connect(_on_slot_cooked)
		slot.burnt.connect(_on_slot_burnt)
		_slots.append(slot)

func try_place(id: String, ing: Dictionary) -> bool:
	if ing.get("appliance", "") != appliance_id:
		return false
	for slot in _slots:
		if slot.accepts(ing):
			slot.place(id, ing, appliance_data)
			return true
	return false

func _on_slot_cooked(ingredient_id: String) -> void:
	emit_signal("item_cooked", ingredient_id)

func _on_slot_burnt(ingredient_id: String) -> void:
	emit_signal("item_burnt", ingredient_id)
