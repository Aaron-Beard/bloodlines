class_name TeamSetup
extends Control
## the screen before a fight: pick up to four units per team, how each one splits its bonus pool and which skills it brings
## your team picks from the babies, the enemy team from the placeholder enemies
## each position is a team_slot card: clicking it opens the creature picker, its skills button opens the skill picker
## start fight saves the picks below and swaps to the fight screen, which reads them

## what you can pick from on each side
const PLAYER_FORM_IDS: Array[String] = ["golem_hatchling", "cat_hatchling", "snake_hatchling"]
## bare bones placeholders, just so the enemy side has something that isn't a baby
const ENEMY_FORM_IDS: Array[String] = ["goblin", "wolf", "slime", "bandit", "hexer", "ogre"]

## what the screen starts on the first time it opens
const DEFAULT_PLAYER_FORMS: Array[String] = ["golem_hatchling", "cat_hatchling", "snake_hatchling"]
const DEFAULT_ENEMY_FORMS: Array[String] = ["goblin", "wolf", "slime"]

const FIGHT_SCENE := "res://src/ui/fight.tscn"
const TEAM_SLOT_SCENE = preload("res://src/ui/team_setup/components/team_slot.tscn")

## the picks handed to the fight screen, front position first, empty slots already left out
## static so they're still here after the scene swap, and when you come back to change them
static var player_forms: Array[String] = []
static var player_spent_offense: Array[int] = []
static var enemy_forms: Array[String] = []
static var enemy_spent_offense: Array[int] = []
## each picked unit's equipped skills, same order as the forms, an empty list for an enemy form since those don't pick
static var player_equipped: Array[Array] = []
static var enemy_equipped: Array[Array] = []

## one entry per slot on each team
var player_slots: Array[Dictionary] = []
var enemy_slots: Array[Dictionary] = []
## the slot the open picker fills in, empty while no picker is open
var selected_slot: Dictionary = {}

@onready var player_slots_container = $MainMargin/MainLayout/TeamsContainer/PlayerPanel/PlayerLayout/PlayerSlots
@onready var enemy_slots_container = $MainMargin/MainLayout/TeamsContainer/EnemyPanel/EnemyLayout/EnemySlots
@onready var start_button = $MainMargin/MainLayout/BottomBar/StartFightButton
@onready var creature_picker: CreaturePicker = $CreaturePicker
@onready var skill_picker: SkillPicker = $SkillPicker


## fills both teams, starting on the saved picks if there are any, otherwise the default teams
func _ready() -> void:
	var player_forms_now := player_forms if not player_forms.is_empty() else DEFAULT_PLAYER_FORMS
	var enemy_forms_now := enemy_forms if not enemy_forms.is_empty() else DEFAULT_ENEMY_FORMS
	player_slots = _build_team(player_slots_container, PLAYER_FORM_IDS, player_forms_now,
			player_spent_offense, player_equipped)
	enemy_slots = _build_team(enemy_slots_container, ENEMY_FORM_IDS, enemy_forms_now,
			enemy_spent_offense, enemy_equipped)

	start_button.pressed.connect(_on_start_pressed)
	creature_picker.creature_confirmed.connect(_on_creature_confirmed)
	skill_picker.skills_confirmed.connect(_on_skills_confirmed)

	_update_start_button()


## one team's cards, one per position, front first
## picks fill the first cards, anything past them starts empty
func _build_team(parent: Control, choices: Array[String], picked: Array[String],
		spent: Array[int], equipped: Array[Array]) -> Array[Dictionary]:

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
		#   it sits in its own box so a slot with no bonus pool can hide all of it
		var totals: Label = slot_node.get_node("VBoxContainer/TotalsLabel")
		var position_label: Label = slot_node.get_node("VBoxContainer/PositionLabel")
		var skills_button: Button = slot_node.get_node("VBoxContainer/Buttons/SkillsButton")
		var clear_button: Button = slot_node.get_node("VBoxContainer/Buttons/ClearButton")

		position_label.text = "Position %d" % (i + 1)

		# Store references for existing game logic
		var entry = {
			"choices": choices,
			"form_id": "",
			"creature_name": creature_name,
			"split": split,
			"slider": slider,
			"totals": totals,
			"skills_button": skills_button,
			"clear_button": clear_button,
			"slot_node": slot_node,
			"equipped": [] as Array[Skill],
			}

		slots.append(entry)

		slot_node.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					selected_slot = entry
					creature_picker.open_picker(choices)
		)

		# Restore saved selection
		if i < picked.size():
			entry["form_id"] = picked[i]

		_on_form_picked(entry)

		# Restore saved stat allocation, after the form since the slider's max depends on it
		if i < spent.size() and _form_in(entry) != null:
			slider.value = _form_in(entry).bonus_pool() - spent[i]

		# same for the saved skills, picking the form equips its first ones
		if i < equipped.size() and _form_in(entry) != null:
			_set_equipped(entry, equipped[i])

		_update_totals(entry)

		slider.value_changed.connect(func(_value: float) -> void:
			_update_totals(entry)
		)

		skills_button.pressed.connect(func():
			selected_slot = entry
			skill_picker.open_picker(_skill_pool(_form_in(entry)), entry["equipped"])
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


## loads a form file from its id
func _load_form(id: String) -> Form:
	return load("res://content/forms/%s.tres" % id)


## a new form starts on an even split and the first skills in its pool
## a form with no bonus pool, like an enemy form, hides the slider and only shows its totals
func _on_form_picked(entry: Dictionary) -> void:
	var form := _form_in(entry)
	var slider: HSlider = entry["slider"]
	entry["split"].visible = form != null and form.bonus_pool() > 0
	if form != null:
		entry["creature_name"].text = form.display_name
		entry["slot_node"].set_creature_image(form.image)
		slider.max_value = form.bonus_pool()
		slider.value = floori(form.bonus_pool() / 2.0)
	else:
		entry["creature_name"].text = "Empty"
		entry["slot_node"].set_creature_image(null)
	_set_equipped(entry, _skill_pool(form).slice(0, Balance.EQUIPPED_SKILL_LIMIT))
	_update_totals(entry)
	_update_start_button()


## a player form's skill pool, empty for an enemy form or an empty slot, since those don't pick skills
func _skill_pool(form: Form) -> Array[Skill]:
	var player_form := form as PlayerForm
	if player_form == null:
		return []
	return player_form.skill_pool


## equips the given skills that are in the slot's pool, kept in pool order and capped at EQUIPPED_SKILL_LIMIT
## the skills button shows how many are on, and is hidden when there's nothing to pick
func _set_equipped(entry: Dictionary, skills: Array) -> void:
	var pool := _skill_pool(_form_in(entry))
	var equipped: Array[Skill] = []
	for skill in pool:
		if skills.has(skill) and equipped.size() < Balance.EQUIPPED_SKILL_LIMIT:
			equipped.append(skill)
	entry["equipped"] = equipped
	var button: Button = entry["skills_button"]
	button.visible = not pool.is_empty()
	button.text = "Skills %d/%d" % [equipped.size(), Balance.EQUIPPED_SKILL_LIMIT]
	button.tooltip_text = "\n".join(equipped.map(func(skill: Skill) -> String: return skill.display_name))


## shows the slot's offense and defense points after the slider's split, blank if the slot is empty
func _update_totals(entry: Dictionary) -> void:
	var form := _form_in(entry)
	var totals: Label = entry["totals"]
	if form == null:
		totals.text = ""
		return
	var spent := _spent_offense(entry)
	totals.text = "off %d / def %d" % [
		form.base_offense_points + spent, form.base_defense_points + form.bonus_pool() - spent]


## both teams need at least one unit
func _update_start_button() -> void:
	if start_button == null:
		return
	start_button.disabled = _picked_count(player_slots) == 0 or _picked_count(enemy_slots) == 0


## how many slots on a team have a form picked
func _picked_count(slots: Array[Dictionary]) -> int:
	var count := 0
	for entry in slots:
		if _form_in(entry) != null:
			count += 1
	return count


## saves both teams' picks and swaps to the fight screen
func _on_start_pressed() -> void:
	_save_team(player_slots, player_forms, player_spent_offense, player_equipped)
	_save_team(enemy_slots, enemy_forms, enemy_spent_offense, enemy_equipped)
	get_tree().change_scene_to_file(FIGHT_SCENE)


## empty slots get skipped, so a gap just moves everyone behind it up a position
func _save_team(slots: Array[Dictionary], forms: Array[String], spent: Array[int],
		equipped: Array[Array]) -> void:
	forms.clear()
	spent.clear()
	equipped.clear()
	for entry in slots:
		var form := _form_in(entry)
		if form != null:
			forms.append(String(form.id))
			spent.append(_spent_offense(entry))
			equipped.append(entry["equipped"].duplicate())


## the slider holds the points going to defense, everything else in the pool goes to offense
func _spent_offense(entry: Dictionary) -> int:
	return _form_in(entry).bonus_pool() - int(entry["slider"].value)


## empties a slot, the remove button
func _clear_team_slot(entry: Dictionary) -> void:
	entry["form_id"] = ""
	_on_form_picked(entry)


## puts the creature picked in the creature picker into the slot that opened it
func _on_creature_confirmed(form_id: String) -> void:
	if selected_slot.is_empty():
		return
	selected_slot["form_id"] = form_id
	_on_form_picked(selected_slot)
	selected_slot = {}


## equips the skills picked in the skill picker on the slot that opened it
func _on_skills_confirmed(skills: Array[Skill]) -> void:
	if selected_slot.is_empty():
		return
	_set_equipped(selected_slot, skills)
	selected_slot = {}
