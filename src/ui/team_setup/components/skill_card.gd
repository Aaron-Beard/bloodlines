class_name SkillCard
extends PanelContainer
## one skill in the skill picker: its name and what it does, click to switch it on or off

signal selected(card: SkillCard)

@onready var skill_name: Label = $VBoxContainer/SkillName
@onready var skill_text: Label = $VBoxContainer/SkillText

var skill: Skill
var is_selected := false


## fills the card in from a skill
func setup(new_skill: Skill) -> void:
	skill = new_skill
	skill_name.text = skill.display_name
	skill_text.text = "\n".join(SkillText.describe(skill))


## a left click asks the picker to switch this card
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit(self)
			accept_event()


## on gets the same blue border as a picked creature card, off gets the solid dark of a team slot
func set_selected(on: bool) -> void:
	is_selected = on
	var style = StyleBoxFlat.new()
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	if on:
		style.bg_color = Color(0.1, 0.16, 0.24)
		style.border_color = Color(0.25, 0.65, 1.0)
	else:
		style.bg_color = Color(0.13, 0.13, 0.13)
		style.border_color = Color(0.22, 0.22, 0.22)
	add_theme_stylebox_override("panel", style)


## grays out a card that can't be switched on because the limit is reached, it stays solid so it's still readable
func set_locked(locked: bool) -> void:
	modulate = Color(0.6, 0.6, 0.6) if locked else Color.WHITE
