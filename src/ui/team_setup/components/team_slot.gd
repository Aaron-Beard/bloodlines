extends PanelContainer

@onready var creature_image: TextureRect = $VBoxContainer/CreatureImage

var normal_style: StyleBox

func _ready() -> void:
	normal_style = get_theme_stylebox("panel").duplicate()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	var hover_style = get_theme_stylebox("panel").duplicate()
	hover_style.border_color = Color(0.2, 0.55, 1.0)
	hover_style.set_border_width_all(1)
	add_theme_stylebox_override("panel", hover_style)

func _on_mouse_exited() -> void:
	add_theme_stylebox_override("panel", normal_style)

func set_creature_image(image: Texture2D) -> void:
	creature_image.texture = image
