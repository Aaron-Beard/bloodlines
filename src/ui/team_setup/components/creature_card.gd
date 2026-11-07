class_name CreatureCard
extends PanelContainer

@onready var creature_image: TextureRect = $VBoxContainer/CreatureImage
@onready var creature_name: Label = $VBoxContainer/CreatureName
@onready var creature_type: Label = $VBoxContainer/CreatureType

signal selected(form_id: String)

var form: Form

func setup(new_form: Form) -> void:
	form = new_form
	
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
