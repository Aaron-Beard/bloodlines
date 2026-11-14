class_name Combat
extends RefCounted
## one whole fight, start to finish
## the ui only reads from this and calls next_actor(), then act(), wait_turn() or auto_act()
## the ui is handled separately based on the numbers and data located within this
## technically this could be run without any ui and just by entering numbers
## every hit that lands with any power does at least 1 (a 0 power hit does 0), and hit chance never drops below FINAL_HIT_CHANCE_MIN
## sudden death makes sure every fight ends, even when both teams heal or keep their shields up
##
## one use of a skill, every step runs for every target before the next step starts:
##   0. targets get locked in, and so does everyone's position, for the whole use
##   1. on use parts, once
##   2. on target parts, for each target
##   3. hit rolls, only attacks that can miss, on enemies and allies alike
##   4. shield checks, attacks only, a clean hit or a graze uses up a charge
##   5. on hit, on miss or on block parts, for each target by how its roll went
##   6. to 8. the hit or heal lands: armor, crit, the mults, then hp changes, always on every target
##   9. on damage or on heal parts, for each target the skill landed on
##   10. on resolution parts, once
##   11. the cooldown gets set, so a speed stack from this turn already counts
##   12. the actor's dots and hots tick, then sudden death takes its share, unless the fight is already over
##   13. the actor's stacks count down, then dead units move to the back
##
## each window reads the units as they were when it opened, so the order of parts inside it only decides what lands first
## once a unit is down, no part acts on it any more
## if the user goes down partway, the rest of the skill doesn't happen
## a unit keeps the position it had at step 0 in every window, even if it or someone in front of it goes down
## positions only really change at the end of the turn, when dead units move to the back

## how many positions each team has, so valid positions are 0 to this minus 1
const POSITIONS_PER_TEAM := 4

## each team in position order, index 0 is the front
## dead units get moved to the back, so everyone behind a fallen unit moves up a position
## the ui can clean this up by either displaying dead units in the back of the formation
## or by hiding them entirely
var player_team: Array[CombatUnit] = []
var enemy_team: Array[CombatUnit] = []

var rng: CombatRng

## the turn order and the fight's clock
var scheduler := AvScheduler.new()

## total turns taken by both teams, no actual gameplay effect
## just used for visualizing things in the demo version of the game currently
var turns_taken := 0

## who acted last, null before the first turn, so the ui can highlight them
## also who wins if both teams go down in the same turn
var last_actor: CombatUnit = null

## whose turn it is right now, null between turns
## set by next_actor(), cleared once they act
var current_actor: CombatUnit = null

## AV in one baseline turn, the unit sudden death is counted in
## AV_BASE / (the player team's average level * GLOBAL_SPEED_MULT), worked out once when the fight starts
## so units going down never move the sudden death clock
var baseline_turn: float

## how many sudden death counters the fight is at, every living unit gets set to this when a new one comes
var sudden_death_count := 0


## sets up the fight with both teams and a seeded rng, then lines the units up on the AV clock
## the teams get copied, so the fight moving units around never changes the caller's lists
## if a team slips through with nobody alive, the fight starts already over (see winning_side())
## and past POSITIONS_PER_TEAM only the first units fight
func _init(players: Array[CombatUnit], enemies: Array[CombatUnit], seed_value: int) -> void:
	assert(not living(players).is_empty() and not living(enemies).is_empty(), "each team needs at least one living unit")
	assert(players.size() <= POSITIONS_PER_TEAM and enemies.size() <= POSITIONS_PER_TEAM,
		"a team can't have more units than positions")
	player_team = fitted_team(players)
	enemy_team = fitted_team(enemies)
	rng = CombatRng.new(seed_value)
	var level_total := 0
	for unit in player_team:
		level_total += unit.level
	var average_level := float(level_total) / player_team.size() if not player_team.is_empty() else 1.0
	baseline_turn = Balance.AV_BASE / (average_level * Balance.GLOBAL_SPEED_MULT)
	scheduler.start(all_units())


## a copy of the team with at most POSITIONS_PER_TEAM units, the first ones
static func fitted_team(team: Array[CombatUnit]) -> Array[CombatUnit]:
	return team.slice(0, POSITIONS_PER_TEAM)


## player team first, then enemies, both front to back
func all_units() -> Array[CombatUnit]:
	var units: Array[CombatUnit] = []
	units.append_array(player_team)
	units.append_array(enemy_team)
	return units


## the unit's own team
func team_of(unit: CombatUnit) -> Array[CombatUnit]:
	return player_team if unit.side == Enums.Side.PLAYER else enemy_team


## the team the unit is fighting against
func other_team(unit: CombatUnit) -> Array[CombatUnit]:
	return enemy_team if unit.side == Enums.Side.PLAYER else player_team


## the units on a team that still have hp, in the same order
static func living(team: Array[CombatUnit]) -> Array[CombatUnit]:
	var alive: Array[CombatUnit] = []
	for unit in team:
		if unit.is_alive():
			alive.append(unit)
	return alive


## position counted among living units only, -1 if the unit is downed
func position_of(unit: CombatUnit) -> int:
	return living(team_of(unit)).find(unit)


## true once one whole team is down
func is_over() -> bool:
	return living(player_team).is_empty() or living(enemy_team).is_empty()


## the side that won, or -1 if nobody has won yet
## if both teams went down in the same turn, the team of the unit that acted wins
## if both teams were down before anyone acted, the player loses
func winning_side() -> int:
	var players_down := living(player_team).is_empty()
	var enemies_down := living(enemy_team).is_empty()
	if players_down and enemies_down:
		return last_actor.side if last_actor != null else Enums.Side.ENEMY
	if enemies_down:
		return Enums.Side.PLAYER
	if players_down:
		return Enums.Side.ENEMY
	return -1


## every living unit in the skill's positions right now, on the team the skill reaches
## a FIXED skill hits all of them, a CHOSEN skill hits one picked from them
## a SELF skill only ever reaches the user
func in_reach(user: CombatUnit, skill: Skill) -> Array[CombatUnit]:
	var reached: Array[CombatUnit] = []
	if skill.reaches == Enums.Reaches.SELF:
		reached.append(user)
		return reached
	var team := other_team(user) if skill.reaches == Enums.Reaches.ENEMIES else team_of(user)
	var alive := living(team)
	for slot in alive.size():
		if not skill.can_target_position(slot):
			continue
		if skill.reaches == Enums.Reaches.ALLIES_NOT_SELF and alive[slot] == user:
			continue
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
		current_actor = scheduler.next_unit(all_units())
		last_actor = current_actor
		turns_taken += 1
		# stacks the actor gets from now until its turn ends skip this turn's count down
		current_actor.effects.own_turn = true
		_update_sudden_death()
	return current_actor


## the current actor uses this skill
## a CHOSEN skill needs the target, it has to be one of in_reach(), a FIXED or SELF skill ignores it
## returns the lines for the fight log
func act(skill: Skill, chosen: CombatUnit = null) -> Array[String]:
	var actor := current_actor
	assert(actor != null, "call next_actor() first")
	assert(usable_skills(actor).has(skill), "that skill can't be used right now")
	# targets get locked in before anything lands, so a FIXED skill still hits everyone it reached
	var targets := in_reach(actor, skill)
	if skill.picks_target():
		assert(targets.has(chosen), "that target isn't in reach")
		targets.clear()
		targets.append(chosen)

	var lines: Array[String] = ["%s uses %s" % [_label(actor), skill.display_name]]
	# one context for the windows that run once, and one for each target that carries its own rolls and mults
	var once := _new_context(actor, null, lines)
	var each: Array[SkillContext] = []
	for target in targets:
		each.append(_new_context(actor, target, lines))
	_use_skill(skill, once, each)

	var cooldown_mult := once.cooldown_mult
	for context in each:
		cooldown_mult *= context.cooldown_mult
	scheduler.set_cooldown(actor, actor.cooldown_for(skill) * cooldown_mult)
	lines.append_array(_end_turn(actor))
	return lines


## the current actor skips their turn, only for when nothing is in reach
## it still counts as a turn, so its dots and hots tick and its stacks count down
func wait_turn() -> Array[String]:
	var actor := current_actor
	assert(actor != null, "call next_actor() first")
	var lines: Array[String] = ["%s has nothing in reach and waits" % _label(actor)]
	scheduler.set_cooldown(actor, actor.base_cooldown())
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
	var skill: Skill = rng.pick(usable)
	var chosen: CombatUnit = null
	if skill.picks_target():
		var reached := in_reach(actor, skill)
		chosen = rng.pick(reached)
	return act(skill, chosen)


## plays one whole turn with nobody picking, for running fights with no screen at all for testing purposes
## useful if we wanted to write a script to simulate many of the same matchup in a row for some reason
## could be helpful for balancing if multiplayer functionality were ever introduced
func step() -> Array[String]:
	if next_actor() == null:
		return []
	return auto_act()


## how many sudden death counters the fight is at after this many baseline turns
## the first one comes at SUDDEN_DEATH_START_BASELINE_TURNS, then one more every SUDDEN_DEATH_BASELINE_TURNS_PER_COUNTER
## with 30 and 2.5 that's one at 30, two at 32.5, three at 35
static func sudden_death_count_at(turns_gone: float) -> int:
	if turns_gone < Balance.SUDDEN_DEATH_START_BASELINE_TURNS:
		return 0
	var past_start := turns_gone - Balance.SUDDEN_DEATH_START_BASELINE_TURNS
	return floori(past_start / Balance.SUDDEN_DEATH_BASELINE_TURNS_PER_COUNTER) + 1


## checks the clock after it jumps, and if a new counter came, every living unit gets set to the fight's count
## set, never added, so a unit that joins or comes back later catches up on the next counter
func _update_sudden_death() -> void:
	var count := sudden_death_count_at(scheduler.elapsed / baseline_turn)
	if count <= sudden_death_count:
		return
	sudden_death_count = count
	for unit in living(all_units()):
		unit.effects.set_counter(EffectTracker.SUDDEN_DEATH, count)


## steps 1 to 10 of one use, stops early if the user goes down
## once holds the windows that run once per use, each holds one context per target
func _use_skill(skill: Skill, once: SkillContext, each: Array[SkillContext]) -> void:
	var user := once.user

	# 1. on use, then every target starts from the user's on use mults
	_run_once(skill, SkillPart.SkillWindow.ON_USE, once, each)
	for context in each:
		context.mults = once.mults.copy()
	if not user.is_alive():
		return

	# 2. on target
	var alive := _still_alive(each)
	for context in alive:
		context.window = SkillPart.SkillWindow.ON_TARGET
	_run_each(skill, alive)
	if not user.is_alive():
		return

	# 3. and 4. hit rolls for every target, then shield checks for every target
	alive = _still_alive(each)
	for context in alive:
		context.hit_type = Damage.roll_hit(user, context.target, skill, context.mults, rng)
		if context.hit_type == Enums.HitType.MISS:
			context.add_line("misses %s" % _label(context.target))
	if skill.is_attack():
		for context in alive:
			if context.hit_type != Enums.HitType.MISS and Damage.is_blocked(context.target):
				context.target.use_shield_charge()
				context.blocked = true
				context.add_line("%s blocks it with a shield (%d left)" % [
					_label(context.target), context.target.shield_charges])

	# 5. on hit, on miss or on block, whichever this target got
	for context in alive:
		if context.blocked:
			context.window = SkillPart.SkillWindow.ON_BLOCK
		elif context.hit_type == Enums.HitType.MISS:
			context.window = SkillPart.SkillWindow.ON_MISS
		else:
			context.window = SkillPart.SkillWindow.ON_HIT
	_run_each(skill, alive)
	if not user.is_alive():
		return

	# 6. to 8. the hit or heal lands on every target that wasn't missed or blocked
	var landed: Array[SkillContext] = []
	for context in _still_alive(each):
		if context.blocked or context.hit_type == Enums.HitType.MISS:
			continue
		match skill.kind:
			Enums.SkillKind.ATTACK:
				_attack(skill, context)
				landed.append(context)
			Enums.SkillKind.HEAL:
				_heal(skill, context)
				landed.append(context)
	var total_damage := 0
	var total_healed := 0
	for context in landed:
		total_damage += context.damage_dealt
		total_healed += context.healed
	for context in [once] + each:
		context.total_damage_dealt = total_damage
		context.total_healed = total_healed
	if not user.is_alive():
		return

	# 9. on damage or on heal, the target that just went down still gets this one
	for context in landed:
		context.window = SkillPart.SkillWindow.ON_DAMAGE if skill.is_attack() else SkillPart.SkillWindow.ON_HEAL
	_run_each(skill, landed)
	if not user.is_alive():
		return

	# 10. on resolution
	_run_once(skill, SkillPart.SkillWindow.ON_RESOLUTION, once, each)


## one hit on one target that got past the roll and the shield, adds its line to the log
func _attack(skill: Skill, context: SkillContext) -> void:
	var target := context.target
	var result := Damage.land(context.user, target, skill, context.hit_type, context.mults, rng)
	context.is_crit = result.is_crit
	context.damage_dealt = target.take_damage(result.amount)
	context.target_died = not target.is_alive()
	var how := "hits"
	if context.hit_type == Enums.HitType.GRAZE:
		how = "grazes"
	elif result.is_crit:
		how = "crits"
	var line := "%s %s for %d" % [how, _label(target), context.damage_dealt]
	if context.target_died:
		line += ", and they go down"
	context.add_line(line)


## one heal on one target, adds its line to the log
## a crit heal says so in the line
func _heal(skill: Skill, context: SkillContext) -> void:
	var target := context.target
	var result := Damage.heal_amount(context.user, target, skill, context.mults, rng)
	context.is_crit = result.is_crit
	context.healed = target.heal(result.amount)
	var how := "crit heals" if result.is_crit else "heals"
	context.add_line("%s %s for %d" % [how, _label(target), context.healed])


## a fresh context for one target, or for the user alone when target is null
## every context shares the same log lines, so they come out in the order things happen
## the positions get locked in here, at step 0, and every window reads those
func _new_context(user: CombatUnit, target: CombatUnit, lines: Array[String]) -> SkillContext:
	var context := SkillContext.new()
	context.user = user
	context.user_position = position_of(user)
	context.target = target
	if target != null:
		context.target_position = position_of(target)
	context.rng = rng
	context.lines = lines
	context.label = _label
	return context


## takes the frozen copies a window reads, from the units as they are right now
## except positions, which stay the ones from step 0
func _freeze(context: SkillContext) -> void:
	context.user_snapshot = SkillContext.Snapshot.new(context.user, context.user_position)
	if context.target != null:
		context.target_snapshot = SkillContext.Snapshot.new(context.target, context.target_position)


## the contexts whose target still has hp
func _still_alive(contexts: Array[SkillContext]) -> Array[SkillContext]:
	var alive: Array[SkillContext] = []
	for context in contexts:
		if context.target.is_alive():
			alive.append(context)
	return alive


## runs a window that happens for each target, each context already says which window it's in
## every target's copies get taken first, then the parts run target by target in list order
func _run_each(skill: Skill, contexts: Array[SkillContext]) -> void:
	for context in contexts:
		_freeze(context)
	for context in contexts:
		for part in skill.parts:
			if part.window != context.window or not _can_run(part, context):
				continue
			if part.condition == null or part.condition.passes(context):
				part.apply(context)


## runs a window that happens once per use, on use or on resolution
## a condition about the target is checked against every target, the way its target_rule setting says
## EACH runs the part once for every target that passes, ANY once if one does, ALL once if all of them do
## the targets that went down still count for the condition, so "target died" works here
func _run_once(skill: Skill, window: SkillPart.SkillWindow, once: SkillContext, each: Array[SkillContext]) -> void:
	for context in [once] + each:
		context.window = window
		_freeze(context)
	for part in skill.parts:
		if part.window != window:
			continue
		var condition := part.condition
		if condition == null or not condition.is_about_target():
			if _can_run(part, once) and (condition == null or condition.passes(once)):
				part.apply(once)
			continue
		match condition.target_rule:
			SkillCondition.TargetRule.EACH:
				for context in each:
					if _can_run(part, context) and condition.passes(context):
						part.apply(context)
			SkillCondition.TargetRule.ANY:
				if _can_run(part, once) and each.any(func(context: SkillContext) -> bool: return condition.passes(context)):
					part.apply(once)
			SkillCondition.TargetRule.ALL:
				if _can_run(part, once) and each.all(func(context: SkillContext) -> bool: return condition.passes(context)):
					part.apply(once)


## false once the user is down, or if the part would act on a target that's down
## a target that went down only keeps the windows after the blow that did it (on damage, on resolution), and only for parts on the user
## in any other window a target that went down skips the rest of it
func _can_run(part: SkillPart, context: SkillContext) -> bool:
	if not context.user.is_alive():
		return false
	if context.target == null or context.target.is_alive():
		return true
	var after_the_blow := context.window == SkillPart.SkillWindow.ON_DAMAGE \
		or context.window == SkillPart.SkillWindow.ON_RESOLUTION
	return after_the_blow and not part.uses_target()


## the end of the actor's turn, after its cooldown is already set
## dots and hots tick first (see dot_hot_change() in combat_unit.gd), then sudden death, then every stack counts down
## if the actor just took out the last enemy the fight is already over, so nothing ticks
## a unit that went down during its own turn doesn't tick either, so a hot can never bring it back
func _end_turn(actor: CombatUnit) -> Array[String]:
	var lines: Array[String] = []
	var net := actor.dot_hot_change()
	if actor.is_alive() and not is_over() and net != 0.0:
		var amount := absf(net)
		if net < 0.0:
			var removed := actor.take_damage(amount)
			var line := "    %s takes %d from dots" % [_label(actor), removed]
			if not actor.is_alive():
				line += ", and they go down"
			lines.append(line)
		else:
			lines.append("    %s heals %d from regen" % [_label(actor), actor.heal(amount)])
	if actor.is_alive() and not is_over() and actor.sudden_death_counters() > 0:
		lines.append(_sudden_death_damage(actor))
	actor.effects.count_down()
	actor.effects.own_turn = false
	current_actor = null
	_move_dead_to_back(player_team)
	_move_dead_to_back(enemy_team)
	return lines


## sudden death's share at the end of the actor's turn: counters * SUDDEN_DEATH_MAX_HP_PER_COUNTER of its max hp
## nothing changes it, no shield, armor, damage taken stacks or crit, and no on damage parts run
## returns its line for the fight log
func _sudden_death_damage(actor: CombatUnit) -> String:
	var amount := actor.sudden_death_counters() * Balance.SUDDEN_DEATH_MAX_HP_PER_COUNTER * actor.max_hp()
	var line := "    %s takes %d from sudden death" % [_label(actor), actor.take_damage(amount)]
	if not actor.is_alive():
		line += ", and they go down"
	return line


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


## how the log names a unit: "your" or "enemy" in front of its form name
func _label(unit: CombatUnit) -> String:
	var owner_word := "your" if unit.side == Enums.Side.PLAYER else "enemy"
	return "%s %s" % [owner_word, unit.form.display_name]
