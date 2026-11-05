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
var start_button: Button


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)

	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 40)
	page.add_child(teams)
	var player_forms_now := player_forms if not player_forms.is_empty() else DEFAULT_PLAYER_FORMS
	var player_spent_now := player_spent_offense
	var enemy_forms_now := enemy_forms if not enemy_forms.is_empty() else DEFAULT_ENEMY_FORMS
	var enemy_spent_now := enemy_spent_offense
	player_slots = _build_team(teams, "your team", PLAYER_FORM_IDS, player_forms_now, player_spent_now)
	enemy_slots = _build_team(teams, "enemy team", ENEMY_FORM_IDS, enemy_forms_now, enemy_spent_now)

	start_button = Button.new()
	start_button.text = "Start fight"
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	start_button.pressed.connect(_on_start_pressed)
	page.add_child(start_button)
	_update_start_button()


## one team's column: a heading, then one row per position, front at the top
## picks fill the first rows, anything past them starts empty
func _build_team(parent: Control, heading: String, choices: Array[String],
		picked: Array[String], spent: Array[int]) -> Array[Dictionary]:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	parent.add_child(column)
	var title := Label.new()
	title.text = "%s, front at the top" % heading
	column.add_child(title)

	var slots: Array[Dictionary] = []
	for slot in Combat.POSITIONS_PER_TEAM:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		column.add_child(row)

		var dropdown := OptionButton.new()
		dropdown.custom_minimum_size = Vector2(150, 0)
		dropdown.add_item("empty")
		for id in choices:
			dropdown.add_item(_load_form(id).display_name)
		row.add_child(dropdown)

		# offense on the left, defense on the right, so dragging toward a side gives that side more
		# that makes the slider's value the bonus points going to defense, _spent_offense() turns it back
		# it sits in its own box so an empty slot can hide all of it
		var split := HBoxContainer.new()
		split.add_theme_constant_override("separation", 10)
		row.add_child(split)
		var offense_word := Label.new()
		offense_word.text = "off"
		split.add_child(offense_word)
		var slider := HSlider.new()
		slider.step = 1
		slider.custom_minimum_size = Vector2(130, 0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		split.add_child(slider)
		var defense_word := Label.new()
		defense_word.text = "def"
		split.add_child(defense_word)

		var totals := Label.new()
		totals.custom_minimum_size = Vector2(140, 0)
		split.add_child(totals)

		var entry := {"choices": choices, "dropdown": dropdown, "split": split, "slider": slider, "totals": totals}
		slots.append(entry)
		if slot < picked.size():
			dropdown.select(choices.find(picked[slot]) + 1)
		_on_form_picked(entry)
		# the slider's max depends on the form, so the saved split goes in after the form
		if slot < spent.size() and _form_in(entry) != null:
			slider.value = _form_in(entry).bonus_pool - spent[slot]
		_update_totals(entry)
		dropdown.item_selected.connect(func(_index: int) -> void: _on_form_picked(entry))
		slider.value_changed.connect(func(_value: float) -> void: _update_totals(entry))
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
