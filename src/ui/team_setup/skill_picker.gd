class_name SkillPicker
extends PopupPanel
## the popup for picking which skills a unit brings, one card per skill in its pool
## up to EQUIPPED_SKILL_LIMIT cards can be on, the rest dim until one is switched off

signal skills_confirmed(skills: Array[Skill])

const SKILL_CARD_SCENE = preload("res://src/ui/team_setup/components/skill_card.tscn")

@onready var picker_title: Label = $PickerLayout/PickerHeader/PickerTitle
@onready var skill_grid: GridContainer = $PickerLayout/SkillGrid
@onready var select_button: Button = $PickerLayout/SelectButton
@onready var close_button: Button = $PickerLayout/PickerHeader/CloseButton

var cards: Array[SkillCard] = []


## hooks up the select and close buttons
func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)
	close_button.pressed.connect(_on_close_pressed)


## shows one card per skill in the pool, with the given skills already on
func open_picker(pool: Array[Skill], equipped: Array) -> void:
	# Remove previously displayed cards.
	for child in skill_grid.get_children():
		skill_grid.remove_child(child)
		child.queue_free()

	cards.clear()

	for skill in pool:
		var card: SkillCard = SKILL_CARD_SCENE.instantiate()
		skill_grid.add_child(card)

		card.setup(skill)
		card.set_selected(equipped.has(skill))
		card.selected.connect(_on_card_selected)

		cards.append(card)

	_refresh()
	popup_centered(Vector2i(800, 600))


## switches a card on or off, but never past the limit
func _on_card_selected(card: SkillCard) -> void:
	if not card.is_selected and _picked().size() >= Balance.EQUIPPED_SKILL_LIMIT:
		return
	card.set_selected(not card.is_selected)
	_refresh()


## the skills switched on right now, in pool order
func _picked() -> Array[Skill]:
	var picked: Array[Skill] = []
	for card in cards:
		if card.is_selected:
			picked.append(card.skill)
	return picked


## updates the count in the title and dims the cards that can't be switched on
func _refresh() -> void:
	var count := _picked().size()
	picker_title.text = "Pick up to %d skills  (%d/%d)" % [
		Balance.EQUIPPED_SKILL_LIMIT, count, Balance.EQUIPPED_SKILL_LIMIT]
	for card in cards:
		card.set_locked(not card.is_selected and count >= Balance.EQUIPPED_SKILL_LIMIT)


## hands the picked skills back and closes
func _on_select_pressed() -> void:
	skills_confirmed.emit(_picked())
	hide()


## closes without changing anything
func _on_close_pressed() -> void:
	hide()
