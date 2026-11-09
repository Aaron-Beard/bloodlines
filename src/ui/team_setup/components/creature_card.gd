class_name CreatureCard
extends PanelContainer

@onready var creature_image: TextureRect = $VBoxContainer/CreatureImage
@onready var creature_name: Label = $VBoxContainer/CreatureName
@onready var creature_type: Label = $VBoxContainer/CreatureType

signal selected(form_id: String)

var form: Form
var form_id: String = ""

func setup(new_form: Form) -> void:
	if new_form == null:
		push_error("CreatureCard received a null Form resource.")
		return

	form = new_form
	form_id = String(new_form.id)

	creature_name.text = form.display_name

	creature_type.text = "PAT: %s | FER: %s | INT: %s" % [
		Enums.AttributeScaling.keys()[form.pat_attribute_scaling],
		Enums.AttributeScaling.keys()[form.fer_attribute_scaling],
		Enums.AttributeScaling.keys()[form.int_attribute_scaling]
	]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit(form.id)
			accept_event()

func set_selected(is_selected: bool) -> void:
	if is_selected:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.16, 0.24)
		style.border_color = Color(0.25, 0.65, 1.0)
		style.set_border_width_all(3)
		style.set_corner_radius_all(6)

		add_theme_stylebox_override("panel", style)
	else:
		remove_theme_stylebox_override("panel")
