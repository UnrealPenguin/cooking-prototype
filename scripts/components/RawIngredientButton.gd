extends Button

signal tapped(ingredient_id: String)

@onready var _icon: TextureRect = %Icon
@onready var _color_swatch: ColorRect = %ColorSwatch

var ingredient_id: String = ""

const _ICON_SEARCH_DIRS := [
	"res://assets/crates/%s.png",
	"res://assets/ingredients/%s.png",
	"res://assets/ingredients/%s_raw.png",
]

func setup(id: String, data: Dictionary) -> void:
	ingredient_id = id
	if not is_node_ready():
		await ready
	var icon_name: String = str(data.get("icon", id))
	var tex: Texture2D = _resolve_texture(icon_name, id)
	if tex != null:
		_icon.texture = tex
		_icon.visible = true
		_color_swatch.visible = false
	else:
		_icon.visible = false
		_color_swatch.color = DataLoader.parse_color(str(data.get("color", "#CCCCCC")))
		_color_swatch.visible = true
	tooltip_text = str(data.get("label", id))

func _resolve_texture(icon_name: String, id: String) -> Texture2D:
	for pattern in _ICON_SEARCH_DIRS:
		var p1: String = pattern % icon_name
		if ResourceLoader.exists(p1):
			return load(p1)
		var p2: String = pattern % id
		if ResourceLoader.exists(p2):
			return load(p2)
	return null

func _ready() -> void:
	pressed.connect(func(): tapped.emit(ingredient_id))
