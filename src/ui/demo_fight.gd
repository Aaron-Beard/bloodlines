extends Control
## the demo screen: your team stacked down the left, the enemies down the right,
## front position at the top of each, and the buttons and fight log in the middle
## everything is built in code, so the .tscn is just this one node
## the screen only reads the fight and calls next_actor(), then act(), wait_turn() or auto_act(), it never does any combat math itself
## enemy turns always play by themselves
## with auto play off the fight stops on your unit's turn and its skill buttons show up in its box
## with auto play on your team picks for itself too

## placeholder teams: the three hatchlings against the three placeholder enemies, same as team setup starts on
## only used when this scene is opened on its own, coming from team setup uses the picks from there
const PLAYER_FORMS: Array[String] = ["golem_hatchling", "cat_hatchling", "snake_hatchling"]
const ENEMY_FORMS: Array[String] = ["goblin", "wolf", "slime"]

## how much of each unit's bonus pool goes to offense, same order as the forms above
const PLAYER_SPENT_OFFENSE: Array[int] = [3, 7, 5]
const ENEMY_SPENT_OFFENSE: Array[int] = [5, 3, 7]

## placeholder, starting level isn't settled yet
const DEMO_LEVEL := 5

const SETUP_SCENE := "res://src/ui/team_setup.tscn"

## seconds between actions that play by themselves
const AUTO_PLAY_DELAY := 0.7

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

const TOOLTIP_BG_COLOR := Color(0.1, 0.1, 0.12)
const TOOLTIP_BORDER_COLOR := Color(0.45, 0.45, 0.5)

var fight: Combat
var seed_value: int

## true while the fight is stopped on your unit's turn
var waiting_for_player := false
## the CHOSEN skill you clicked, while you pick who it hits, null otherwise
var picking_target_for: Skill = null

var player_column: VBoxContainer
var enemy_column: VBoxContainer
var status_label: Label
var turn_order_row: HFlowContainer
var fight_log: RichTextLabel
var auto_button: Button
var auto_timer: Timer


func _ready() -> void:
	_build_layout()
	_new_fight()


## godot's default tooltip background is see-through, which made the skill tooltips hard to read over the log
## a theme on this node only changes what it sets, everything else keeps the default look
func _set_tooltip_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = TOOLTIP_BG_COLOR
	style.border_color = TOOLTIP_BORDER_COLOR
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	theme = Theme.new()
	theme.set_stylebox("panel", "TooltipPanel", style)


func _build_layout() -> void:
	_set_tooltip_style()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)

	# three columns: your team, the buttons and log, the enemy team
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 24)
	margin.add_child(page)

	# a team of four doesn't fit down the screen, so each column scrolls
	player_column = _add_team_column(page)

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 12)
	page.add_child(middle)

	enemy_column = _add_team_column(page)

	# buttons and the seed / action count
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	middle.add_child(controls)

	auto_button = Button.new()
	auto_button.text = "Auto play"
	auto_button.toggle_mode = true
	auto_button.toggled.connect(_on_auto_toggled)
	controls.add_child(auto_button)

	var new_fight_button := Button.new()
	new_fight_button.text = "New fight"
	new_fight_button.pressed.connect(_new_fight)
	controls.add_child(new_fight_button)

	var setup_button := Button.new()
	setup_button.text = "Team setup"
	setup_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(SETUP_SCENE))
	controls.add_child(setup_button)

	# on its own line, since next to the buttons it pushed the enemy column off the screen
	status_label = Label.new()
	middle.add_child(status_label)

	# who goes next, left to right
	turn_order_row = HFlowContainer.new()
	middle.add_child(turn_order_row)

	# the fight log fills the rest of the screen and keeps scrolled to the bottom
	fight_log = RichTextLabel.new()
	fight_log.bbcode_enabled = true
	fight_log.scroll_following = true
	fight_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(fight_log)

	auto_timer = Timer.new()
	auto_timer.wait_time = AUTO_PLAY_DELAY
	auto_timer.timeout.connect(_play_next_turn)
	add_child(auto_timer)


func _new_fight() -> void:
	# the screen picks a random seed, but the fight itself only ever rolls with its own seeded rng
	seed_value = randi()
	var players: Array[CombatUnit]
	var enemies: Array[CombatUnit]
	if TeamSetup.player_forms.is_empty():
		players = _make_team(PLAYER_FORMS, PLAYER_SPENT_OFFENSE, Enums.Side.PLAYER)
		enemies = _make_team(ENEMY_FORMS, ENEMY_SPENT_OFFENSE, Enums.Side.ENEMY)
	else:
		players = _make_team(TeamSetup.player_forms, TeamSetup.player_spent_offense, Enums.Side.PLAYER)
		enemies = _make_team(TeamSetup.enemy_forms, TeamSetup.enemy_spent_offense, Enums.Side.ENEMY)
	fight = Combat.new(players, enemies, seed_value)

	waiting_for_player = false
	picking_target_for = null
	auto_button.set_pressed_no_signal(false)
	fight_log.clear()
	fight_log.append_text("new fight, seed %d\n" % seed_value)
	auto_timer.start()
	_refresh()


func _make_team(form_ids: Array[String], spent_offense: Array[int], side: Enums.Side) -> Array[CombatUnit]:
	var team: Array[CombatUnit] = []
	for i in form_ids.size():
		var form: Form = load("res://content/forms/%s.tres" % form_ids[i])
		var unit := CombatUnit.new(form, DEMO_LEVEL, side, spent_offense[i])
		# the pools are all small enough to just equip the whole thing for now
		unit.equipped_skills.assign(form.skill_pool)
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


## a FIXED skill goes off right away, a CHOSEN one waits for you to click a target
func _on_skill_pressed(skill: Skill) -> void:
	if skill.targeting == Enums.Targeting.CHOSEN:
		picking_target_for = skill
		_refresh()
	else:
		_show_action(fight.act(skill))


func _on_box_clicked(event: InputEvent, unit: CombatUnit) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_action(fight.act(picking_target_for, unit))


func _on_cancel_pressed() -> void:
	picking_target_for = null
	_refresh()


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


func _refresh() -> void:
	_fill_column(player_column, fight.player_team)
	_fill_column(enemy_column, fight.enemy_team)
	status_label.text = "seed %d   turns %d" % [seed_value, fight.turns_taken]
	_fill_turn_order()


## one small box per living unit, in the order they'll act
## each unit only shows its next turn, so it's always exact
## after a unit acts it just lands wherever its new AV puts it
func _fill_turn_order() -> void:
	for child in turn_order_row.get_children():
		turn_order_row.remove_child(child)
		child.queue_free()
	for unit in AvScheduler.turn_order(fight.all_units()):
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = PLAYER_COLOR if unit.side == Enums.Side.PLAYER else ENEMY_COLOR
		style.set_content_margin_all(4)
		if unit == fight.current_actor:
			style.set_border_width_all(2)
			style.border_color = LAST_ACTOR_BORDER_COLOR
		chip.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		# position instead of the name, so two of the same species on one team still look different
		# the color already says which team
		var when := "now" if unit == fight.current_actor else "%d AV" % roundi(unit.av)
		label.text = "pos %d\n%s" % [fight.position_of(unit), when]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		chip.add_child(label)
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


## a column of unit boxes inside a scroll box, only scrolls up and down
func _add_team_column(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	scroll.add_child(column)
	return column


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


func _make_box(unit: CombatUnit) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(300, 0)

	var style := StyleBoxFlat.new()
	if not unit.is_alive():
		style.bg_color = DEAD_COLOR
	elif unit.side == Enums.Side.PLAYER:
		style.bg_color = PLAYER_COLOR
	else:
		style.bg_color = ENEMY_COLOR
	style.set_content_margin_all(10)
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

	var lines := VBoxContainer.new()
	box.add_child(lines)
	# name and position share a line so three boxes fit down the screen
	if unit.is_alive():
		_add_label(lines, "%s, position %d" % [unit.form.display_name, fight.position_of(unit)])
	else:
		_add_label(lines, "%s, down" % unit.form.display_name)
	# while you pick a target, every box you could click shows your odds against it
	if _is_pickable(unit) and picking_target_for.rolls_hit_chance():
		var odds := Label.new()
		odds.text = _odds_text(fight.current_actor, unit, picking_target_for)
		odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		odds.add_theme_color_override("font_color", TARGET_BORDER_COLOR)
		lines.add_child(odds)

	_add_label(lines, "HP %d / %d" % [unit.hp, unit.max_hp()])
	var hp_bar := ProgressBar.new()
	hp_bar.max_value = unit.max_hp()
	hp_bar.value = unit.hp
	hp_bar.show_percentage = false
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.custom_minimum_size = Vector2(0, 12)
	lines.add_child(hp_bar)

	if unit.is_alive():
		_add_label(lines, "next turn in %d AV" % roundi(unit.av))
		_add_label(lines, _shield_text(unit))
	# every buff, debuff, dot, hot and counter on the unit, wraps if there's a lot
	var effect_text := ", ".join(unit.effects.describe())
	if unit.is_alive() and effect_text != "":
		var effect_label := Label.new()
		effect_label.text = effect_text
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect_label.add_theme_color_override("font_color", EFFECT_TEXT_COLOR)
		lines.add_child(effect_label)
	# stats stay decimals in combat, they only get rounded here for showing
	_add_label(lines, "ARM %.0f   PEN %.0f" % [unit.stat(Enums.Stat.ARMOR), unit.stat(Enums.Stat.PEN)])
	_add_label(lines, "ACC %.0f   DOD %.0f   SPD %.0f" % [
		unit.stat(Enums.Stat.ACCURACY), unit.stat(Enums.Stat.DODGE), unit.stat(Enums.Stat.SPEED)])
	if waiting_for_player and unit == fight.current_actor:
		_add_turn_buttons(lines, unit)
	return box


## the buttons for your unit's turn, at the bottom of its box
## a skill with nothing in reach is grayed out
func _add_turn_buttons(parent: Control, unit: CombatUnit) -> void:
	if picking_target_for != null:
		_add_label(parent, "pick a target for %s" % picking_target_for.display_name)
		var cancel := Button.new()
		cancel.text = "Cancel"
		cancel.pressed.connect(_on_cancel_pressed)
		parent.add_child(cancel)
		return
	# the buttons wrap side by side so the box doesn't push the one below it off the screen
	var buttons := HFlowContainer.new()
	parent.add_child(buttons)
	var usable := fight.usable_skills(unit)
	for skill in unit.skills():
		var button := Button.new()
		button.text = skill.display_name
		button.tooltip_text = _skill_text(skill, unit)
		button.disabled = not usable.has(skill)
		button.pressed.connect(_on_skill_pressed.bind(skill))
		buttons.add_child(button)
	if usable.is_empty():
		var wait := Button.new()
		wait.text = "Wait"
		wait.pressed.connect(_on_wait_pressed)
		buttons.add_child(wait)


## everything shown when you hover a skill button:
## its numbers, who it reaches, what effects it puts on, and the odds against everyone in reach right now
func _skill_text(skill: Skill, user: CombatUnit) -> String:
	var lines: Array[String] = []
	var kind_word: String = Enums.SkillKind.keys()[skill.kind].to_lower()
	lines.append("%s, %s" % [skill.display_name, kind_word])

	# accuracy only means something for skills that roll to hit
	var numbers: Array[String] = []
	if skill.kind != Enums.SkillKind.STATUS:
		numbers.append("power %.0f" % skill.base_power)
	if skill.rolls_hit_chance():
		numbers.append("accuracy %d%%" % roundi(skill.base_hit_chance * 100.0))
	numbers.append("cooldown x%.2f" % skill.cooldown_mult)
	lines.append("   ".join(numbers))

	var verb := "heals" if skill.kind == Enums.SkillKind.HEAL else "hits"
	if skill.kind == Enums.SkillKind.STATUS:
		verb = "affects"
	var how_many := "one" if skill.targeting == Enums.Targeting.CHOSEN else "every"
	var side := "ally" if skill.targets_allies else "enemy"
	var slots := ", ".join(skill.valid_target_positions.map(func(slot): return str(slot)))
	var position_word := "position" if skill.valid_target_positions.size() == 1 else "positions"
	lines.append("%s %s %s in %s %s" % [verb, how_many, side, position_word, slots])

	if skill.unmissable:
		lines.append("can't miss")
	if skill.lifesteal_percent > 0.0:
		lines.append("lifesteal %d%% of the damage dealt" % roundi(skill.lifesteal_percent * 100.0))
	var target_word := "on the target" if skill.targeting == Enums.Targeting.CHOSEN else "on each target"
	for spec in skill.effects:
		var where := "on yourself"
		if not spec.targets_self:
			where = target_word + (" if it lands" if skill.is_attack() else "")
		lines.append("%s: %s" % [where, _effect_text(spec)])

	# the odds against everyone this would reach if used right now
	if skill.rolls_hit_chance():
		for target in fight.in_reach(user, skill):
			lines.append("vs %s, position %d: %s" % [
				target.form.display_name, fight.position_of(target), _odds_text(user, target, skill)])
	return "\n".join(lines)


## one effect in words, like "poison x1 for 3 turns"
func _effect_text(spec: EffectSpec) -> String:
	match spec.kind:
		EffectSpec.Kind.CLEANSE:
			return "cleanse %d debuffs" % spec.amount
		EffectSpec.Kind.PURGE:
			return "purge %d buffs" % spec.amount
		EffectSpec.Kind.SHIELD:
			if spec.shield_mode == Enums.ShieldMode.GRANT:
				return "shield up to %d" % spec.shield_value
			return "shield set to %d" % spec.shield_value
		EffectSpec.Kind.COUNTER:
			return "%s %+d" % [spec.counter_id, spec.amount]
		_:
			return "%s x%d for %d turns" % [
				EffectTracker.label_of(spec.kind, spec.stat, spec.direction, spec.dot_type),
				spec.stacks, spec.duration]


## hit, graze and miss chances from the double hit roll, plus a warning if a shield would take it
## "hit" here means a clean hit, both rolls landing
func _odds_text(user: CombatUnit, target: CombatUnit, skill: Skill) -> String:
	var p := Damage.final_hit_chance(user, target, skill)
	var text := "hit %d%%  graze %d%%  miss %d%%" % [
		roundi(p * p * 100.0), roundi(2.0 * p * (1.0 - p) * 100.0), roundi((1.0 - p) * (1.0 - p) * 100.0)]
	if target.shield_charges > 0:
		text += ", shield blocks it"
	return text


func _shield_text(unit: CombatUnit) -> String:
	var text := "shield %d / %d" % [unit.shield_charges, unit.shield_capacity()]
	if unit.shield_charges < unit.shield_capacity():
		text += ", next in %d AV" % roundi(unit.av_until_next_shield_charge())
	return text


func _add_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
