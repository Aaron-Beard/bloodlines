class_name Combat
extends RefCounted
## one whole fight, start to finish
## the ui only reads from this and calls next_actor(), then act(), wait_turn() or auto_act()
## the ui is handled separately based on the numbers and data located within this
## technically this could be run without any ui and just by entering numbers 
## cut down for the demo: no sudden death mechanic yet
## every hit that lands does at least 1, and hit chance never drops below FINAL_HIT_CHANCE_MIN
## in all likelihood, this will never matter, but it's good to know in general
## heals and hots can keep a fight going forever until sudden death is in, so for now only the Geode heals and enemies never do
##
## one turn in order:
##   1. the skill lands on its targets: damage or heal, then the effects on the target
##   2. lifesteal, then the self effects
##   3. the cooldown gets set, so a self speed buff already shortens the wait after this turn
##   4. the actor's dots and hots tick, unless that skill just ended the fight
##   5. the actor's stacks count down, after the cooldown, so a 1 turn speed stack still counts for that wait

## how many positions each team has, so valid positions are 0 to this minus 1
const POSITIONS_PER_TEAM := 4

## each team in position order, index 0 is the front
## dead units get moved to the back, so everyone behind a fallen unit moves up a position
## the ui can clean this up by either displaying dead units in the back of the formation
## or by hiding them entirely
var player_team: Array[CombatUnit] = []
var enemy_team: Array[CombatUnit] = []

var rng: CombatRng
## total turns taken by both teams, no actual gameplay effect
## just used for visualizing things in the demo version of the game currently
## nothing in combat uses it, so it can be removed once development moves past the demo
var turns_taken := 0

## who acted last, null before the first turn, so the ui can highlight them
var last_actor: CombatUnit = null

## whose turn it is right now, null between turns
## set by next_actor(), cleared once they act
var current_actor: CombatUnit = null


func _init(players: Array[CombatUnit], enemies: Array[CombatUnit], seed_value: int) -> void:
	assert(players.size() <= POSITIONS_PER_TEAM and enemies.size() <= POSITIONS_PER_TEAM,
		"a team can't have more units than positions")
	player_team = players
	enemy_team = enemies
	rng = CombatRng.new(seed_value)
	AvScheduler.start(all_units())


## player team first, then enemies, both front to back
func all_units() -> Array[CombatUnit]:
	var units: Array[CombatUnit] = []
	units.append_array(player_team)
	units.append_array(enemy_team)
	return units


func team_of(unit: CombatUnit) -> Array[CombatUnit]:
	return player_team if unit.side == Enums.Side.PLAYER else enemy_team


func other_team(unit: CombatUnit) -> Array[CombatUnit]:
	return enemy_team if unit.side == Enums.Side.PLAYER else player_team


static func living(team: Array[CombatUnit]) -> Array[CombatUnit]:
	var alive: Array[CombatUnit] = []
	for unit in team:
		if unit.is_alive():
			alive.append(unit)
	return alive


## position counted among living units only, -1 if the unit is downed
func position_of(unit: CombatUnit) -> int:
	return living(team_of(unit)).find(unit)


func is_over() -> bool:
	return living(player_team).is_empty() or living(enemy_team).is_empty()


## the side that won, or -1 if nobody has won yet
## both teams can't go down at once right now, _end_turn() skips the tick once the fight is over
## if something like thorns or recoil ever makes that possible, it needs a real tie rule here
func winning_side() -> int:
	if living(enemy_team).is_empty():
		return Enums.Side.PLAYER
	if living(player_team).is_empty():
		return Enums.Side.ENEMY
	return -1


## every living unit in the skill's positions right now
## a FIXED skill hits all of them, a CHOSEN skill hits one picked from them
func in_reach(user: CombatUnit, skill: Skill) -> Array[CombatUnit]:
	var team := team_of(user) if skill.targets_allies else other_team(user)
	var alive := living(team)
	var reached: Array[CombatUnit] = []
	for slot in alive.size():
		if skill.can_target_position(slot):
			reached.append(alive[slot])
	return reached


## the skills this unit could use right now
## any skill with somebody in reach
func usable_skills(unit: CombatUnit) -> Array[Skill]:
	var usable: Array[Skill] = []
	for skill in unit.skills():
		if not in_reach(unit, skill).is_empty():
			usable.append(skill)
	return usable


## a turn is two halves: next_actor() moves the clock to whoever is next,
## then act(), auto_act() or wait_turn() finishes it
## in between the fight just sits there, which is where the player gets to pick
## calling it again before the turn is finished gives back the same unit
## null once the fight is over
func next_actor() -> CombatUnit:
	if is_over():
		return null
	if current_actor == null:
		current_actor = AvScheduler.next_unit(all_units())
		last_actor = current_actor
		turns_taken += 1
	return current_actor


## the current actor uses this skill
## a CHOSEN skill needs the target, it has to be one of in_reach(), a FIXED skill ignores it
## returns the lines for the fight log
func act(skill: Skill, chosen: CombatUnit = null) -> Array[String]:
	var actor := current_actor
	assert(actor != null, "call next_actor() first")
	assert(usable_skills(actor).has(skill), "that skill can't be used right now")
	# targets get locked in before anything lands, so a FIXED skill still hits everyone it reached
	var targets := in_reach(actor, skill)
	if skill.targeting == Enums.Targeting.CHOSEN:
		assert(targets.has(chosen), "that target isn't in reach")
		targets.clear()
		targets.append(chosen)

	var lines: Array[String] = []
	lines.append("%s uses %s" % [_label(actor), skill.display_name])
	# hp the attack actually took off, summed over every target, for lifesteal
	var dealt := 0
	for target in targets:
		var landed := true
		match skill.kind:
			Enums.SkillKind.ATTACK:
				var removed := _attack(actor, target, skill, lines)
				landed = removed >= 0
				dealt += maxi(0, removed)
			Enums.SkillKind.HEAL:
				_heal(actor, target, skill, lines)
		# a miss or a shield block means none of the target's effects land either
		if landed and target.is_alive():
			_apply_effects(skill, target, false, lines)
	if skill.lifesteal_percent > 0.0 and dealt > 0:
		var healed := actor.heal(dealt * skill.lifesteal_percent)
		lines.append("    %s heals %d from lifesteal" % [_label(actor), healed])
	_apply_effects(skill, actor, true, lines)
	actor.av = actor.cooldown_for(skill)
	lines.append_array(_end_turn(actor))
	return lines


## the current actor skips their turn, only for when nothing is in reach
## it still counts as a turn, so its dots and hots tick and its stacks count down
func wait_turn() -> Array[String]:
	var actor := current_actor
	assert(actor != null, "call next_actor() first")
	var lines: Array[String] = ["%s has nothing in reach and waits" % _label(actor)]
	actor.av = actor.base_cooldown()
	lines.append_array(_end_turn(actor))
	return lines


## the current actor picks for themselves: a random usable skill,
## and a random target in reach for a CHOSEN one
## enemies always play like this, and so does your team on auto play
## in the future, different ai types can be made, so that the ai can act smarter or execute certain skills according to preplanned criteria
func auto_act() -> Array[String]:
	var actor := current_actor
	assert(actor != null, "call next_actor() first")
	var usable := usable_skills(actor)
	if usable.is_empty():
		return wait_turn()
	var skill := usable[rng.pick_index(usable.size())]
	var chosen: CombatUnit = null
	if skill.targeting == Enums.Targeting.CHOSEN:
		var reached := in_reach(actor, skill)
		chosen = reached[rng.pick_index(reached.size())]
	return act(skill, chosen)


## plays one whole turn with nobody picking, for running fights with no screen at all for testing purposes
## useful if we wanted to write a script to simulate many of the same matchup in a row for some reason
## could be helpful for balancing if multiplayer functionality were ever introduced
func step() -> Array[String]:
	if next_actor() == null:
		return []
	return auto_act()


## one attack on one target, adds its line to the log
## returns the hp that came off, or -1 for a miss or a shield block so the effects know not to land
func _attack(attacker: CombatUnit, target: CombatUnit, skill: Skill, lines: Array[String]) -> int:
	var result := Damage.resolve(attacker, target, skill, rng)
	if result.hit_type == Enums.HitType.MISS:
		lines.append("    misses %s" % _label(target))
		return -1
	if result.blocked:
		target.use_shield_charge()
		lines.append("    %s blocks it with a shield (%d left)" % [_label(target), target.shield_charges])
		return -1
	var removed := target.take_damage(result.damage)
	var how := "hits"
	if result.hit_type == Enums.HitType.GRAZE:
		how = "grazes"
	elif result.is_crit:
		how = "crits"
	var line := "    %s %s for %d" % [how, _label(target), removed]
	if not target.is_alive():
		line += ", and they go down"
	lines.append(line)
	return removed


func _heal(healer: CombatUnit, target: CombatUnit, skill: Skill, lines: Array[String]) -> void:
	var result := Damage.resolve_heal(healer, skill, rng)
	var restored := target.heal(result.damage)
	var how := "crit heals" if result.is_crit else "heals"
	lines.append("    %s %s for %d" % [how, _label(target), restored])


## the skill's effects that go on this unit
## self ones go on the user once per use, the rest go on each target the skill landed on
func _apply_effects(skill: Skill, unit: CombatUnit, self_ones: bool, lines: Array[String]) -> void:
	for spec in skill.effects:
		if spec.targets_self == self_ones:
			lines.append(_apply_effect(spec, unit))


func _apply_effect(spec: EffectSpec, unit: CombatUnit) -> String:
	match spec.kind:
		EffectSpec.Kind.CLEANSE:
			var removed := unit.effects.remove_debuffs(spec.amount)
			return "    %s gets %d debuffs cleansed" % [_label(unit), removed]
		EffectSpec.Kind.PURGE:
			var removed := unit.effects.remove_buffs(spec.amount)
			return "    %s gets %d buffs purged" % [_label(unit), removed]
		EffectSpec.Kind.SHIELD:
			unit.apply_shield(spec.shield_mode, spec.shield_value)
			return "    %s's shield is now %d" % [_label(unit), unit.shield_charges]
		EffectSpec.Kind.COUNTER:
			unit.effects.change_counter(spec.counter_id, spec.amount)
			return "    %s's %s is now %d" % [_label(unit), spec.counter_id, unit.effects.counter(spec.counter_id)]
		_:
			unit.effects.add(spec)
			return "    %s gets %s x%d for %d turns" % [
				_label(unit), EffectTracker.label_of(spec.kind, spec.stat, spec.direction, spec.dot_type),
				spec.stacks, spec.duration]


## the end of the actor's turn, after its cooldown is already set
## dots and hots tick first, then every stack counts down
## dots and hots net out into one change, so they cancel each other out and it only rounds once
## the dot part goes up and down with the actor's damage taken stacks, so damage taken up helps dot builds too
## dots aren't affected by any buffs to the stats of the attacker
## if the actor just took out the last enemy the fight is already over, so nothing ticks
## this prevents both of the last two units from dying simultaneously
func _end_turn(actor: CombatUnit) -> Array[String]:
	var lines: Array[String] = []
	var tick := Balance.DOT_HOT_HP_PERCENT * actor.max_hp()
	var dot_amount := actor.effects.dot_stacks() * tick * actor.effects.damage_taken_mult()
	var hot_amount := actor.effects.hot_stacks() * tick
	var net := hot_amount - dot_amount
	if not is_over() and actor.effects.dot_stacks() + actor.effects.hot_stacks() > 0 and net != 0.0:
		var amount := absf(net)
		if net < 0.0:
			var removed := actor.take_damage(amount)
			var line := "    %s takes %d from dots" % [_label(actor), removed]
			if not actor.is_alive():
				line += ", and they go down"
			lines.append(line)
		else:
			lines.append("    %s heals %d from regen" % [_label(actor), actor.heal(amount)])
	actor.effects.count_down()
	current_actor = null
	_move_dead_to_back(player_team)
	_move_dead_to_back(enemy_team)
	return lines


## living units keep their order and dead ones go to the back
## may replace later with something that removes them entirely from the combat. for now it should work fine
## the ui can always just hide the dead units if need be
func _move_dead_to_back(team: Array[CombatUnit]) -> void:
	var alive := living(team)
	var dead: Array[CombatUnit] = []
	for unit in team:
		if not unit.is_alive():
			dead.append(unit)
	team.clear()
	team.append_array(alive)
	team.append_array(dead)


func _label(unit: CombatUnit) -> String:
	var owner_word := "your" if unit.side == Enums.Side.PLAYER else "enemy"
	return "%s %s" % [owner_word, unit.form.display_name]
