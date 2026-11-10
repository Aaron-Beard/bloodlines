class_name CreaturePicker
extends PopupPanel

signal creature_confirmed(form_id: String)

const CREATURE_CARD_SCENE = preload("res://src/ui/team_setup/components/creature_card.tscn")

@onready var creature_grid: GridContainer = $PickerLayout/CreatureGrid
@onready var select_button: Button = $PickerLayout/SelectButton
@onready var close_button: Button = $PickerLayout/PickerHeader/CloseButton

var selected_form_id: String = ""
var cards: Array = []


func _ready() -> void:
	select_button.disabled = true

	select_button.pressed.connect(_on_select_pressed)
	close_button.pressed.connect(_on_close_pressed)
	


func open_picker(form_ids: Array[String]) -> void:
	selected_form_id = ""
	select_button.disabled = true

	# Remove previously displayed cards.
	for child in creature_grid.get_children():
		child.queue_free()

	cards.clear()

	# Create a card for every available creature.
	for id in form_ids:
		var form: Form = load("res://content/forms/%s.tres" % id)

		if form == null:
			continue

		var card = CREATURE_CARD_SCENE.instantiate()
		creature_grid.add_child(card)

		card.setup(form)
		card.set_selected(false)
		card.selected.connect(_on_card_selected)

		cards.append(card)

	popup_centered(Vector2i(800, 600))

func _on_card_selected(form_id: String) -> void:
	selected_form_id = form_id
	select_button.disabled = false

	# Highlight the selected card and deselect the others.
	for card in cards:
		card.set_selected(card.form_id == form_id)


func _on_select_pressed() -> void:
	if selected_form_id == "":
		return

	creature_confirmed.emit(selected_form_id)
	hide()


func _on_close_pressed() -> void:
	hide()
