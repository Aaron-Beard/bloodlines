extends Control
## the fight screen: your team stacked down the left, the enemies down the right,
## front position at the top of each, and the buttons and fight log in the middle
## the layout lives in fight.tscn, each unit's card and turn order chip is its own small scene this fills in
## the screen only reads the fight and calls next_actor(), then act(), wait_turn() or auto_act(), it never does any combat math itself
## enemy turns always play by themselves
## with auto play off the fight stops on your unit's turn and its skill buttons show up in its box
## with auto play on your team picks for itself too

## placeholder teams: the three hatchlings against the three placeholder enemies, same as team setup starts on
## only used when this scene is opened on its own, coming from team setup uses the picks from there
const PLAYER_FORMS: Array[String] = ["golem_hatchling", "cat_hatchling", "snake_hatchling"]
const ENEMY_FORMS: Array[String] = ["goblin", "wolf", "slime"]

## how much of each unit's bonus pool goes to offense, same order as the forms above
## enemy forms have no bonus pool, so they spend nothing
const PLAYER_SPENT_OFFENSE: Array[int] = [3, 7, 5]
const ENEMY_SPENT_OFFENSE: Array[int] = [0, 0, 0]

## placeholder, starting level isn't settled yet
const DEMO_LEVEL := 5

const SETUP_SCENE := "res://src/ui/team_setup/team_setup.tscn"

## the small scenes filled in once per unit, per turn order spot and per skill
const UNIT_CARD_SCENE := preload("res://src/ui/unit_card.tscn")
const TURN_CHIP_SCENE := preload("res://src/ui/turn_chip.tscn")
const SKILL_BUTTON_SCENE := preload("res://src/ui/skill_button.tscn")

const PLAYER_COLOR := Color(0.18, 0.28, 0.45)
const ENEMY_COLOR := Color(0.45, 0.18, 0.18)
const DEAD_COLOR := Color(0.2, 0.2, 0.2)
const LAST_ACTOR_BORDER_COLOR := Color(1.0, 0.85, 0.3)
const TARGET_BORDER_COLOR := Color(0.4, 1.0, 0.5)
const EFFECT_TEXT_COLOR := Color(1.0, 0.9, 0.6)

## fight log colors, demo polish only
const LOG_PLAYER_COLOR := Color(0.6, 0.78, 1.0)
const LOG_ENEMY_COLOR := Color(1.0, 0.62, 0.62)
const LOG_CRIT_COLOR := Color(1.0, 0.8, 0.3)
const LOG_DOWN_COLOR := Color(1.0, 0.35, 0.35)
const LOG_DOT_COLOR := Color(0.85, 0.6, 1.0)
const LOG_HEAL_COLOR := Color(0.55, 1.0, 0.55)
const LOG_MISS_COLOR := Color(0.65, 0.65, 0.65)

var fight: Combat
var seed_value: int

## true while the fight is stopped on your unit's turn
var waiting_for_player := false
## the CHOSEN skill you clicked, while you pick who it hits, null otherwise
var picking_target_for: Skill = null

## the unit columns sit in scroll boxes, since a team of four doesn't fit down the screen
@onready var player_column: VBoxContainer = %PlayerColumn
@onready var enemy_column: VBoxContainer = %EnemyColumn
## seed and turn count, on its own line, since next to the buttons it pushed the enemy column off the screen
@onready var status_label: Label = %StatusLabel
## who goes next, left to right
@onready var turn_order_row: HFlowContainer = %TurnOrderRow
## fills the rest of the middle and keeps scrolled to the bottom
@onready var fight_log: RichTextLabel = %FightLog
@onready var auto_button: Button = %AutoButton
## its wait time is the seconds between actions that play by themselves
@onready var auto_timer: Timer = %AutoTimer


## starts the first fight, the screen itself is already laid out in the scene
func _ready() -> void:
	_new_fight()


## back to team setup, which still has the picks
func _on_setup_pressed() -> void:
	get_tree().change_scene_to_file(SETUP_SCENE)


## starts a fresh fight on a new random seed, with the picks from team setup or else the placeholder teams
## clears the log and turns auto play off
func _new_fight() -> void:
	# the screen picks a random seed, but the fight itself only ever rolls with its own seeded rng
	seed_value = randi()
	var players: Array[CombatUnit]
	var enemies: Array[CombatUnit]
	if TeamSetup.player_forms.is_empty():
		players = _make_team(PLAYER_FORMS, PLAYER_SPENT_OFFENSE, [], Enums.Side.PLAYER)
		enemies = _make_team(ENEMY_FORMS, ENEMY_SPENT_OFFENSE, [], Enums.Side.ENEMY)
	else:
		players = _make_team(TeamSetup.player_forms, TeamSetup.player_spent_offense,
				TeamSetup.player_equipped, Enums.Side.PLAYER)
		enemies = _make_team(TeamSetup.enemy_forms, TeamSetup.enemy_spent_offense,
				TeamSetup.enemy_equipped, Enums.Side.ENEMY)
	fight = Combat.new(players, enemies, seed_value)

	waiting_for_player = false
	picking_target_for = null
	auto_button.set_pressed_no_signal(false)
	fight_log.clear()
	fight_log.append_text("new fight, seed %d\n" % seed_value)
	auto_timer.start()
	_refresh()


## builds a team from form ids at the demo level, each unit with the offense it spent
## a player form equips the skills picked for it in team setup, or the first ones in its pool without picks
## an enemy form equips nothing, its fixed skills all come in free
func _make_team(form_ids: Array[String], spent_offense: Array[int], equipped: Array[Array],
		side: Enums.Side) -> Array[CombatUnit]:
	var team: Array[CombatUnit] = []
	for i in form_ids.size():
		var form: Form = load("res://content/forms/%s.tres" % form_ids[i])
		var skills: Array[Skill] = []
		var player_form := form as PlayerForm
		if i < equipped.size():
			skills.assign(equipped[i])
		elif player_form != null:
			skills = CombatUnit.fitted_skills(player_form.skill_pool)
		var unit := CombatUnit.new(form, DEMO_LEVEL, side, spent_offense[i], skills)
		team.append(unit)
	return team


## runs on the timer: either plays the turn for whoever is next, or stops and waits for you
func _play_next_turn() -> void:
	var actor := fight.next_actor()
	if actor == null:
		return
	if actor.side == Enums.Side.PLAYER and not auto_button.button_pressed:
		auto_timer.stop()
		waiting_for_player = true
		_refresh()
		return
	_show_action(fight.auto_act())


## adds an action's lines to the log and ends the turn on screen
## once the fight is over it writes the result and stops the timer, otherwise it restarts the timer if it was stopped
func _show_action(lines: Array[String]) -> void:
	for line in lines:
		fight_log.append_text(_colored(line) + "\n")
	# a blank line after every action so the log doesn't turn into one wall of text
	fight_log.append_text("\n")
	waiting_for_player = false
	picking_target_for = null
	if fight.is_over():
		auto_timer.stop()
		fight_log.append_text("[b]%s[/b]\n" % _result_text())
	elif auto_timer.is_stopped():
		auto_timer.start()
	_refresh()


## demo polish only: colors a fight log line by reading its words
## the "uses" line takes its team's color, the lines under it are colored by what happened
## combat still only hands over plain text, so this can be deleted without touching anything else
func _colored(line: String) -> String:
	var color := Color.WHITE
	var bold := false
	if not line.begins_with(" "):
		color = LOG_PLAYER_COLOR if line.begins_with("your") else LOG_ENEMY_COLOR
	elif line.contains("go down"):
		color = LOG_DOWN_COLOR
		bold = true
	elif line.contains("crit"):
		color = LOG_CRIT_COLOR
		bold = true
	elif line.contains("from dots"):
		color = LOG_DOT_COLOR
	elif line.contains("heals"):
		color = LOG_HEAL_COLOR
	elif line.contains("misses") or line.contains("blocks"):
		color = LOG_MISS_COLOR
	elif line.contains(" gets ") or line.contains("shield is now") or line.contains(" is now "):
		color = EFFECT_TEXT_COLOR
	var text := "[color=#%s]%s[/color]" % [color.to_html(false), line]
	return "[b]%s[/b]" % text if bold else text


## turning auto play on while the fight is waiting on you plays that turn too
func _on_auto_toggled(on: bool) -> void:
	if on and waiting_for_player:
		_show_action(fight.auto_act())


## a FIXED or SELF skill goes off right away, a CHOSEN one waits for you to click a target
func _on_skill_pressed(skill: Skill) -> void:
	if skill.picks_target():
		picking_target_for = skill
		_refresh()
	else:
		_show_action(fight.act(skill))


## a left click on a unit box uses the skill you're picking a target for on that unit
func _on_box_clicked(event: InputEvent, unit: CombatUnit) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_action(fight.act(picking_target_for, unit))


## drops the skill you were picking a target for, back to the skill buttons
func _on_cancel_pressed() -> void:
	picking_target_for = null
	_refresh()


## your unit skips its turn
func _on_wait_pressed() -> void:
	_show_action(fight.wait_turn())


## true if this box can be clicked as the target for the skill you're picking for
func _is_pickable(unit: CombatUnit) -> bool:
	return picking_target_for != null and fight.in_reach(fight.current_actor, picking_target_for).has(unit)


## only called once the fight is over, so one side has always won
func _result_text() -> String:
	if fight.winning_side() == Enums.Side.PLAYER:
		return "your team wins"
	return "the enemy team wins"


## redraws both team columns, the status line and the turn order
func _refresh() -> void:
	_fill_column(player_column, fight.player_team)
	_fill_column(enemy_column, fight.enemy_team)
	status_label.text = "seed %d   turns %d" % [seed_value, fight.turns_taken]
	if fight.sudden_death_count > 0:
		status_label.text += "   sudden death %d" % fight.sudden_death_count
	_fill_turn_order()


## one small box per living unit, in the order they'll act
## each unit only shows its next turn, so it's always exact
## after a unit acts it just lands wherever its new AV puts it
func _fill_turn_order() -> void:
	for child in turn_order_row.get_children():
		turn_order_row.remove_child(child)
		child.queue_free()
	for unit in fight.scheduler.turn_order(fight.all_units()):
		var chip: PanelContainer = TURN_CHIP_SCENE.instantiate()
		# every chip shares the scene's style, so each one colors its own copy
		var style: StyleBoxFlat = chip.get_theme_stylebox("panel").duplicate()
		style.bg_color = PLAYER_COLOR if unit.side == Enums.Side.PLAYER else ENEMY_COLOR
		if unit == fight.current_actor:
			style.set_border_width_all(2)
			style.border_color = LAST_ACTOR_BORDER_COLOR
		chip.add_theme_stylebox_override("panel", style)
		# position instead of the name, so two of the same species on one team still look different
		# the color already says which team
		var when := "now" if unit == fight.current_actor else "%d AV" % roundi(unit.av)
		_card_label(chip, "ChipLabel").text = "pos %d\n%s" % [fight.position_of(unit), when]
		turn_order_row.add_child(chip)


## rebuilds one team's boxes from scratch, front at the top, it's only a handful of nodes
## dead units are already at the back of the team, so they end up at the bottom
func _fill_column(column: VBoxContainer, team: Array[CombatUnit]) -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	for unit in team:
		var box := _make_box(unit)
		column.add_child(box)
		if unit == fight.current_actor:
			_scroll_to(box)


## keeps whoever's acting on screen when their box is further down the column
## waits two frames first so the boxes have their sizes and places, one frame wasn't enough
func _scroll_to(box: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# the box may already be gone if the screen got rebuilt again in the meantime
	if is_instance_valid(box) and box.is_inside_tree():
		var scroll: ScrollContainer = box.get_parent().get_parent()
		var bottom := box.position.y + box.size.y
		if bottom > scroll.scroll_vertical + scroll.size.y:
			scroll.scroll_vertical = ceili(bottom - scroll.size.y)
		elif box.position.y < scroll.scroll_vertical:
			scroll.scroll_vertical = floori(box.position.y)


## one unit's box: name and position, hp, AV until its next turn, shield, effects and stats
## a target you can click and the last actor get a border, and the unit whose turn it is gets its skill buttons
## the box is a unit_card.tscn, the lines it doesn't need stay hidden
func _make_box(unit: CombatUnit) -> Control:
	var box: PanelContainer = UNIT_CARD_SCENE.instantiate()

	# every box shares the scene's style, so each one colors its own copy
	var style: StyleBoxFlat = box.get_theme_stylebox("panel").duplicate()
	if not unit.is_alive():
		style.bg_color = DEAD_COLOR
	elif unit.side == Enums.Side.PLAYER:
		style.bg_color = PLAYER_COLOR
	else:
		style.bg_color = ENEMY_COLOR
	if _is_pickable(unit):
		style.set_border_width_all(3)
		style.border_color = TARGET_BORDER_COLOR
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		box.gui_input.connect(_on_box_clicked.bind(unit))
	elif unit == fight.last_actor:
		style.set_border_width_all(3)
		style.border_color = LAST_ACTOR_BORDER_COLOR
	box.add_theme_stylebox_override("panel", style)

	# name and position share a line so three boxes fit down the screen
	if unit.is_alive():
		_card_label(box, "NameLabel").text = "%s, position %d" % [unit.form.display_name, fight.position_of(unit)]
	else:
		_card_label(box, "NameLabel").text = "%s, down" % unit.form.display_name
	# while you pick a target, every box you could click shows your odds against it
	if _is_pickable(unit) and picking_target_for.rolls_hit_chance():
		var odds := _card_label(box, "OddsLabel")
		odds.text = _odds_text(fight.current_actor, unit, picking_target_for)
		odds.show()

	_card_label(box, "HpLabel").text = "HP %d / %d" % [unit.hp, unit.max_hp()]
	var hp_bar: ProgressBar = box.get_node("%HpBar")
	hp_bar.max_value = unit.max_hp()
	hp_bar.value = unit.hp

	if unit.is_alive():
		_card_label(box, "AvLabel").text = "next turn in %d AV" % roundi(unit.av)
		_card_label(box, "ShieldLabel").text = _shield_text(unit)
	else:
		_card_label(box, "AvLabel").hide()
		_card_label(box, "ShieldLabel").hide()
	# every buff, debuff, dot, hot and counter on the unit, wraps if there's a lot
	var effect_text := ", ".join(unit.effects.describe())
	if unit.is_alive() and effect_text != "":
		var effect_label := _card_label(box, "EffectsLabel")
		effect_label.text = effect_text
		effect_label.show()
	# stats stay decimals in combat, they only get rounded here for showing
	_card_label(box, "ArmorLabel").text = "ARM %.0f   PEN %.0f" % [
		unit.stat(Enums.Stat.ARMOR), unit.stat(Enums.Stat.PEN)]
	_card_label(box, "AccuracyLabel").text = "ACC %.0f   DOD %.0f   SPD %.0f" % [
		unit.stat(Enums.Stat.ACCURACY), unit.stat(Enums.Stat.DODGE), unit.stat(Enums.Stat.SPEED)]
	if waiting_for_player and unit == fight.current_actor:
		_show_turn_buttons(box, unit)
	return box


## the buttons for your unit's turn, at the bottom of its box
## a skill with nothing in reach is grayed out
func _show_turn_buttons(box: Control, unit: CombatUnit) -> void:
	if picking_target_for != null:
		var pick_label := _card_label(box, "PickLabel")
		pick_label.text = "pick a target for %s" % picking_target_for.display_name
		pick_label.show()
		var cancel: Button = box.get_node("%CancelButton")
		cancel.pressed.connect(_on_cancel_pressed)
		cancel.show()
		return
	# the buttons wrap side by side so the box doesn't push the one below it off the screen
	var buttons: HFlowContainer = box.get_node("%SkillButtons")
	buttons.show()
	var usable := fight.usable_skills(unit)
	for skill in unit.skills():
		var button: Button = SKILL_BUTTON_SCENE.instantiate()
		button.text = skill.display_name
		button.tooltip_text = _skill_text(skill, unit)
		button.disabled = not usable.has(skill)
		button.pressed.connect(_on_skill_pressed.bind(skill))
		buttons.add_child(button)
	# wait sits in the scene before the skills, so it moves to the end of the row
	if usable.is_empty():
		var wait: Button = box.get_node("%WaitButton")
		wait.pressed.connect(_on_wait_pressed)
		wait.show()
		buttons.move_child(wait, -1)


## everything shown when you hover a skill button:
## what SkillText says about it, then the odds against everyone in reach right now
func _skill_text(skill: Skill, user: CombatUnit) -> String:
	var lines := SkillText.describe(skill)
	# the odds against everyone this would reach if used right now
	if skill.rolls_hit_chance():
		for target in fight.in_reach(user, skill):
			lines.append("vs %s, position %d: %s" % [
				target.form.display_name, fight.position_of(target), _odds_text(user, target, skill)])
	return "\n".join(lines)


## hit, graze and miss chances from the double hit roll, plus a warning if a shield would take it
## "hit" here means a clean hit, both rolls landing
func _odds_text(user: CombatUnit, target: CombatUnit, skill: Skill) -> String:
	var p := Damage.final_hit_chance(user, target, skill, Damage.Mults.new())
	var text := "hit %d%%  graze %d%%  miss %d%%" % [
		roundi(p * p * 100.0), roundi(2.0 * p * (1.0 - p) * 100.0), roundi((1.0 - p) * (1.0 - p) * 100.0)]
	if target.shield_charges > 0:
		text += ", shield blocks it"
	return text


## shield charges out of capacity, plus the AV until the next charge when it isn't full
func _shield_text(unit: CombatUnit) -> String:
	var text := "shield %d / %d" % [unit.shield_charges, unit.shield_capacity()]
	if unit.shield_charges < unit.shield_capacity():
		text += ", next in %d AV" % roundi(unit.av_until_next_shield_charge())
	return text


## one of a unit card's or turn chip's labels, by its unique name in that scene
func _card_label(card: Node, label_name: String) -> Label:
	return card.get_node("%" + label_name)
