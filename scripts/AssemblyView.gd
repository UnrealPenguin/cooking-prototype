extends Control
class_name AssemblyView

signal served(card: OrderCard)
signal cancelled

var _order_card: OrderCard = null

@onready var _title: Label = %Title
@onready var _list: VBoxContainer = %ComponentList
@onready var _serve_btn: Button = %ServeBtn
@onready var _cancel_btn: Button = %CancelBtn

func _ready() -> void:
	visible = false
	_serve_btn.pressed.connect(_on_serve)
	_cancel_btn.pressed.connect(_on_cancel)

func open_for(card: OrderCard) -> void:
	_order_card = card
	_title.text = "Assemble: " + str(card.recipe.get("label", ""))
	for child in _list.get_children():
		child.queue_free()
	for comp in card.recipe.get("components", []):
		var ing_id: String = comp.get("ingredient", "")
		var ing := DataLoader.get_ingredient(ing_id)
		var state: String = comp.get("state", "prepped")
		var text: String = ing.get("label", ing_id)
		if state == "prepped":
			text = ing.get("prepped_label", text)
		elif state == "cooked":
			text = ing.get("cooked_label", text)
		var row := HBoxContainer.new()
		var color := ColorRect.new()
		color.color = DataLoader.parse_color(str(ing.get("color", "#CCCCCC")))
		color.custom_minimum_size = Vector2(24, 24)
		row.add_child(color)
		var lbl := Label.new()
		lbl.text = "  " + text + "  ✓"
		lbl.add_theme_font_size_override("font_size", 20)
		row.add_child(lbl)
		_list.add_child(row)
	visible = true

func close_view() -> void:
	visible = false
	_order_card = null

func _on_serve() -> void:
	var c := _order_card
	close_view()
	emit_signal("served", c)

func _on_cancel() -> void:
	close_view()
	emit_signal("cancelled")
