extends Node

var ingredients: Dictionary = {}
var appliances: Dictionary = {}
var recipes: Dictionary = {}
var levels: Array = []

func _ready() -> void:
	ingredients = _load_json("res://data/ingredients.json")
	appliances = _load_json("res://data/appliances.json")
	recipes = _load_json("res://data/recipes.json")
	levels = _load_json("res://data/levels.json")

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("Invalid JSON in: %s" % path)
		return {}
	return parsed

func get_ingredient(id: String) -> Dictionary:
	return ingredients.get(id, {})

func get_appliance(id: String) -> Dictionary:
	return appliances.get(id, {})

func get_recipe(id: String) -> Dictionary:
	return recipes.get(id, {})

func get_level(id: int) -> Dictionary:
	for lvl in levels:
		if int(lvl.get("id", -1)) == id:
			return lvl
	return {}

func parse_color(hex_string: String) -> Color:
	return Color.html(hex_string) if hex_string.begins_with("#") else Color(hex_string)
