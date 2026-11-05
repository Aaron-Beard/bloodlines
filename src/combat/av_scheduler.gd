class_name AvScheduler
extends RefCounted
## this determines the turn order
## every unit has some AV (action value) left before its next turn
## the unit with the least AV left goes next, and the clock moves forward by that much for everyone
## after acting, a unit's AV gets set to its cooldown for the skill it used
## so a unit with twice the speed gets exactly twice the frequency of turns
## shield regen runs on the same system, every living unit regens by each jump when a new turn starts


## everyone starts a full base cooldown away from their first turn, so faster units go first
static func start(units: Array[CombatUnit]) -> void:
	for unit in units:
		unit.av = unit.base_cooldown()


## picks who acts next and moves the clock forward to that moment
## ties are broken by player units before enemy, and front of party to back
## ties are probably extremely uncommon anyways, so this will be rare
## really only necessary so there is some way at all to resolve when a tie occurs
## returns null if nobody is alive
static func next_unit(units: Array[CombatUnit]) -> CombatUnit:
	var next: CombatUnit = null
	for unit in units:
		if unit.is_alive() and (next == null or unit.av < next.av):
			next = unit
	if next == null:
		return null
	var elapsed := next.av
	for unit in units:
		if unit.is_alive():
			unit.av -= elapsed
			unit.regen_shield(elapsed)
	return next


## every living unit in the order they'll act, using the same tie breaks as next_unit()
## each unit shows up once, at its next turn, nothing gets changed
## later turns aren't shown since the exact AV depends on which skill gets used
static func turn_order(units: Array[CombatUnit]) -> Array[CombatUnit]:
	var order: Array[CombatUnit] = []
	for unit in units:
		if unit.is_alive():
			order.append(unit)
	# units come in player first then front to back, so on a tie the one earlier in it goes first
	order.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		if a.av != b.av:
			return a.av < b.av
		return units.find(a) < units.find(b))
	return order
