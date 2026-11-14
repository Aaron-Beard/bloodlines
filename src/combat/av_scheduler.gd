class_name AvScheduler
extends RefCounted
## this determines the turn order, and it is the one place that keeps track of time in a fight
## every unit has some AV (action value) left before its next turn
## the unit with the least AV left goes next, and the clock jumps forward by that much for everyone
## after acting, a unit's AV gets set to its cooldown for the skill it used
## so a unit with twice the speed gets exactly twice as many turns
## shield recharge runs on the same clock, every living unit recharges by the size of each jump
## units get passed in on every call, player team first then front to back,
## so the order always matches the teams as they are right now


## total AV gone by since the fight started, sudden death will be counted from this
var elapsed: float = 0.0

## how far the clock jumped to reach the current actor, 0 when it was tied with the last one
var last_jump: float = 0.0


## everyone starts a full base cooldown away from their first turn, as if they all just acted at once
## so faster units go first, and the clock starts back at 0
func start(units: Array[CombatUnit]) -> void:
	elapsed = 0.0
	last_jump = 0.0
	for unit in units:
		unit.av = unit.base_cooldown()


## picks who acts next and moves the clock forward to that moment
## every living unit loses that much AV and recharges its shield by the same amount
## dead units are skipped, so their AV and shields stay frozen
## returns null if nobody is alive
func next_unit(units: Array[CombatUnit]) -> CombatUnit:
	var order := turn_order(units)
	if order.is_empty():
		last_jump = 0.0
		return null
	var next := order[0]
	last_jump = next.av
	elapsed += last_jump
	for unit in order:
		unit.av -= last_jump
		unit.recharge_shield(last_jump)
	return next


## the unit just finished its turn and now waits this much AV before its next one
## speed stacks only matter here, when the wait gets set, so the AV a unit has left never jumps
func set_cooldown(unit: CombatUnit, cooldown: float) -> void:
	unit.av = cooldown


## every living unit in the order they'll act, each once, at its next turn, nothing gets changed
## ties go to the player team first, then the front position, which is the order units come in
## AVs are compared exactly, so a tie only counts when the two numbers are exactly the same
## later turns aren't shown since the exact AV depends on which skill gets used
func turn_order(units: Array[CombatUnit]) -> Array[CombatUnit]:
	var order: Array[CombatUnit] = []
	for unit in units:
		if unit.is_alive():
			order.append(unit)
	order.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		if a.av != b.av:
			return a.av < b.av
		return units.find(a) < units.find(b))
	return order
