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

## one entry per slot on each team, each one holding that slot's dropdown, slider and totals label
var player_slots: Array[Dictionary] = []
var enemy_slots: Array[Dictionary] = []

@onready var player_slots_container = $MainMargin/MainLayout/TeamsContainer/PlayerPanel/PlayerLayout/PlayerSlots
@onready var enemy_slots_container = $MainMargin/MainLayout/TeamsContainer/EnemyPanel/EnemyLayout/EnemySlots
@onready var start_button = $MainMargin/MainLayout/BottomBar/StartFightButton
const CREATURE_CARD_SCENE = preload("res://src/ui/team_setup/components/creature_card.tscn")
const TEAM_SLOT_SCENE = preload("res://src/ui/team_setup/components/team_slot.tscn")

func _ready() -> void:
	player_slots = _build_team(player_slots_container, "Player Team", PLAYER_FORM_IDS, player_forms, player_spent_offense)
	enemy_slots = _build_team(enemy_slots_container, "Enemy Team", ENEMY_FORM_IDS, enemy_forms, enemy_spent_offense)

	_build_creature_roster()
	start_button.pressed.connect(_on_start_pressed)

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
		var dropdown: OptionButton = slot_node.get_node("VBoxContainer/CreatureDropdown")
		var split: HBoxContainer = slot_node.get_node("VBoxContainer/Split")
		var slider: HSlider = slot_node.get_node("VBoxContainer/Split/AllocationSlider")
		# ^ offense on the left, defense on the right, so dragging toward a side gives that side more
		#   that makes the slider's value the bonus points going to defense, _spent_offense() turns it back
		#   it sits in its own box so an empty slot can hide all of it
		var totals: Label = slot_node.get_node("VBoxContainer/TotalsLabel")
		var position_label: Label = slot_node.get_node("VBoxContainer/PositionLabel")
		
		position_label.text = "Position %d" % (i + 1)
		
		# Populate the dropdown
		dropdown.add_item("empty")
		
		for id in choices:
			dropdown.add_item(_load_form(id).display_name)
		
		# Store references for existing game logic
		var entry = {
			"choices": choices,
			"dropdown": dropdown,
			"split": split,
			"slider": slider,
			"totals": totals
			}
		
		slots.append(entry)
		# Restore saved selection
		if i < picked.size():
			dropdown.select(choices.find(picked[i]) + 1)

		_on_form_picked(entry)

		# Restore saved stat allocation
		if i < spent.size() and _form_in(entry) != null:
			slider.value = _form_in(entry).bonus_pool - spent[i]

		_update_totals(entry)

		# Connect signals
		dropdown.item_selected.connect(func(_index: int) -> void:
			_on_form_picked(entry)
		)

		slider.value_changed.connect(func(_value: float) -> void:
			_update_totals(entry)
		)

	return slots


## null if the slot is empty
func _form_in(entry: Dictionary) -> Form:
	var index: int = entry["dropdown"].selected
	if index <= 0:
		return null
	return _load_form(entry["choices"][index - 1])


func _load_form(id: String) -> Form:
	return load("res://content/forms/%s.tres" % id)


## a new form starts on an even split
func _on_form_picked(entry: Dictionary) -> void:
	var form := _form_in(entry)
	var slider: HSlider = entry["slider"]
	entry["split"].visible = form != null
	if form != null:
		slider.max_value = form.bonus_pool
		slider.value = floori(form.bonus_pool / 2.0)
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


func _build_creature_roster() -> void:
	var roster = $MainMargin/MainLayout/TeamsContainer/PlayerPanel/PlayerLayout/CreatureRoster

	for id in PLAYER_FORM_IDS:
		var form = _load_form(id)
		var card = CREATURE_CARD_SCENE.instantiate()

		roster.add_child(card)
		card.setup(form)
		
		card.selected.connect(_on_creature_card_selected)

func _on_creature_card_selected(form_id: String) -> void:
	for entry in player_slots:
		var dropdown: OptionButton = entry["dropdown"]

		if dropdown.selected == 0:
			dropdown.select(PLAYER_FORM_IDS.find(form_id) + 1)
			_on_form_picked(entry)
			return
