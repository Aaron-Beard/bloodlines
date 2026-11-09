class_name TeamSetup
extends Control
## the screen before a fight: pick up to four units per team and how each one splits its bonus pool
## your team picks from the babies, the enemy team from the placeholder enemies
## everything is built in code, so the .tscn is just this one node
## start fight saves the picks below and swaps to the fight screen, which reads them

## what you can pick from on each side
const PLAYER_FORM_IDS: Array[String] = ["golem_hatchling", "cat_hatchling", "snake_hatchling"]
## bare bones placeholders, just so the enemy side has something that isn't a baby
const ENEMY_FORM_IDS: Array[String] = ["goblin", "wolf", "slime"]

## what the screen starts on the first time it opens
const DEFAULT_PLAYER_FORMS: Array[String] = ["golem_hatchling", "cat_hatchling", "snake_hatchling"]
const DEFAULT_ENEMY_FORMS: Array[String] = ["goblin", "wolf", "slime"]

const FIGHT_SCENE := "res://src/ui/demo_fight.tscn"

## the picks handed to the fight screen, front position first, empty slots already left out
## static so they're still here after the scene swap, and when you come back to change them
static var player_forms: Array[String] = []
static var player_spent_offense: Array[int] = []
static var enemy_forms: Array[String] = []
static var enemy_spent_offense: Array[int] = []

## one entry per slot on each team
var player_slots: Array[Dictionary] = []
var enemy_slots: Array[Dictionary] = []
var selected_player_slot: Dictionary = {}
var selected_enemy_slot: Dictionary = {}

@onready var player_slots_container = $MainMargin/MainLayout/TeamsContainer/PlayerPanel/PlayerLayout/PlayerSlots
@onready var enemy_slots_container = $MainMargin/MainLayout/TeamsContainer/EnemyPanel/EnemyLayout/EnemySlots
@onready var start_button = $MainMargin/MainLayout/BottomBar/StartFightButton
@onready var creature_picker: CreaturePicker = $CreaturePicker
const TEAM_SLOT_SCENE = preload("res://src/ui/team_setup/components/team_slot.tscn")


func _ready() -> void:
	var initial_enemy_forms: Array[String] = enemy_forms
	if initial_enemy_forms.is_empty():
		initial_enemy_forms = DEFAULT_ENEMY_FORMS
	player_slots = _build_team(player_slots_container, "Player Team", PLAYER_FORM_IDS, player_forms, player_spent_offense)
	enemy_slots = _build_team(enemy_slots_container, "Enemy Team", ENEMY_FORM_IDS, initial_enemy_forms, enemy_spent_offense)

	
	start_button.pressed.connect(_on_start_pressed)
	creature_picker.creature_confirmed.connect(_on_creature_confirmed)

	_update_start_button()


## one team's column: a heading, then one row per position, front at the top
## picks fill the first rows, anything past them starts empty
func _build_team(parent: Control, heading: String, choices: Array[String],
		picked: Array[String], spent: Array[int]) -> Array[Dictionary]:

	var slots: Array[Dictionary] = []
	
	for i in range(Combat.POSITIONS_PER_TEAM):
		# create a TeamSlot instance
		var slot_node = TEAM_SLOT_SCENE.instantiate()
		parent.add_child(slot_node)
		

		# Get references to the nodes inside TeamSlot
		var split: HBoxContainer = slot_node.get_node("VBoxContainer/Split")
		var creature_name: Label = slot_node.get_node("VBoxContainer/CreatureName")
		var slider: HSlider = slot_node.get_node("VBoxContainer/Split/AllocationSlider")
		# ^ offense on the left, defense on the right, so dragging toward a side gives that side more
		#   that makes the slider's value the bonus points going to defense, _spent_offense() turns it back
		#   it sits in its own box so an empty slot can hide all of it
		var totals: Label = slot_node.get_node("VBoxContainer/TotalsLabel")
		var position_label: Label = slot_node.get_node("VBoxContainer/PositionLabel")
		var clear_button: Button = slot_node.get_node("VBoxContainer/ClearButton")
		
		position_label.text = "Position %d" % (i + 1)
		
		# Store references for existing game logic
		var entry = {
			"choices": choices,
			"form_id": "",
			"creature_name": creature_name,
			"split": split,
			"slider": slider,
			"totals": totals,
			"clear_button": clear_button
			}
		
		slots.append(entry)
		
		if parent == player_slots_container:
			slot_node.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton:
					if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
						selected_player_slot = entry
						selected_enemy_slot = {}
						creature_picker.open_picker(PLAYER_FORM_IDS)
			)
			
		elif parent == enemy_slots_container:
			slot_node.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton:
					if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
						selected_enemy_slot = entry
						selected_player_slot = {}
						creature_picker.open_picker(ENEMY_FORM_IDS)
			)

		# Restore saved selection
		if i < picked.size():
			entry["form_id"] = picked[i]

		_on_form_picked(entry)

		# Restore saved stat allocation
		if i < spent.size() and _form_in(entry) != null:
			slider.value = _form_in(entry).bonus_pool - spent[i]

		_update_totals(entry)

		slider.value_changed.connect(func(_value: float) -> void:
			_update_totals(entry)
		)
		
		clear_button.pressed.connect(func():
			_clear_team_slot(entry)
		)

	return slots


## null if the slot is empty
func _form_in(entry: Dictionary) -> Form:
	var id: String = entry["form_id"]

	if id == "":
		return null

	return _load_form(id)


func _load_form(id: String) -> Form:
	return load("res://content/forms/%s.tres" % id)


## a new form starts on an even split
func _on_form_picked(entry: Dictionary) -> void:
	var form := _form_in(entry)
	var slider: HSlider = entry["slider"]
	entry["split"].visible = form != null
	if form != null:
		entry["creature_name"].text = form.display_name
		slider.max_value = form.bonus_pool
		slider.value = floori(form.bonus_pool / 2.0)
	else:
		entry["creature_name"].text = "Empty"
	_update_totals(entry)
	_update_start_button()


func _update_totals(entry: Dictionary) -> void:
	var form := _form_in(entry)
	var totals: Label = entry["totals"]
	if form == null:
		totals.text = ""
		return
	var spent := _spent_offense(entry)
	totals.text = "off %d / def %d" % [
		form.base_offense_points + spent, form.base_defense_points + form.bonus_pool - spent]


## both teams need at least one unit
func _update_start_button() -> void:
	if start_button == null:
		return
	start_button.disabled = _picked_count(player_slots) == 0 or _picked_count(enemy_slots) == 0


func _picked_count(slots: Array[Dictionary]) -> int:
	var count := 0
	for entry in slots:
		if _form_in(entry) != null:
			count += 1
	return count


func _on_start_pressed() -> void:
	_save_team(player_slots, player_forms, player_spent_offense)
	_save_team(enemy_slots, enemy_forms, enemy_spent_offense)
	get_tree().change_scene_to_file(FIGHT_SCENE)


## empty slots get skipped, so a gap just moves everyone behind it up a position
func _save_team(slots: Array[Dictionary], forms: Array[String], spent: Array[int]) -> void:
	forms.clear()
	spent.clear()
	for entry in slots:
		var form := _form_in(entry)
		if form != null:
			forms.append(String(form.id))
			spent.append(_spent_offense(entry))


## the slider holds the points going to defense, everything else in the pool goes to offense
func _spent_offense(entry: Dictionary) -> int:
	return _form_in(entry).bonus_pool - int(entry["slider"].value)


func _clear_team_slot(entry: Dictionary) -> void:
	entry["form_id"] = ""
	_on_form_picked(entry)

func _on_creature_confirmed(form_id: String) -> void:
	if not selected_player_slot.is_empty():
		selected_player_slot["form_id"] = form_id
		_on_form_picked(selected_player_slot)
		selected_player_slot = {}

	elif not selected_enemy_slot.is_empty():
		selected_enemy_slot["form_id"] = form_id
		_on_form_picked(selected_enemy_slot)
		selected_enemy_slot = {}
