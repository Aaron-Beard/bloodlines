class_name EffectTracker
extends RefCounted
## every buff, debuff, dot, hot and counter on one unit
## cut down for the demo, the full version is yet to be implemented
##
## a stack only remembers what it is and how many turns it has left
## how strong it is comes from balance constants, never from the stack itself or the applying skill
## buffs and debuffs are kept apart, up to EFFECT_STACK_LIMIT of each per effect
## one of each cancels out exactly, since a buff multiplies by the ratio and a debuff divides by it
## bleed, burn and poison all share one limit, hots have their own
## counters have no duration and no limit, and cleanse and purge never touch them


## one stack of one effect
class Stack:
	var kind: EffectSpec.Kind
	## only means something for STAT
	var stat: Enums.Stat
	## +1 raises the number, -1 lowers it, unused for dots and hots
	var direction: int
	## only means something for DOT
	var dot_type: Enums.DotType
	var turns_left: int


var stacks: Array[Stack] = []
var counters: Dictionary[StringName, int] = {}


## adds a STAT, DAMAGE_DEALT, DAMAGE_TAKEN, DOT or HOT effect
## new stacks go on first, then the shortest ones left get dropped until the group is back at the limit
## so a fresh stack never gets thrown away in favor of one that's about to run out
func add(spec: EffectSpec) -> void:
	for i in spec.stacks:
		var stack := Stack.new()
		stack.kind = spec.kind
		stack.stat = spec.stat
		stack.direction = spec.direction
		stack.dot_type = spec.dot_type
		stack.turns_left = spec.duration
		stacks.append(stack)
	_trim(_group_of(stacks[-1]))


## true for anything good for the unit holding it
## note for DAMAGE_TAKEN: it's the only one where reducing is good rather than increasing
func is_buff(stack: Stack) -> bool:
	match stack.kind:
		EffectSpec.Kind.HOT:
			return true
		EffectSpec.Kind.DOT:
			return false
		EffectSpec.Kind.DAMAGE_TAKEN:
			return stack.direction < 0
		_:
			return stack.direction > 0


## cleanse: takes off up to this many debuff stacks, dots included
## returns how many actually came off
func remove_debuffs(count: int) -> int:
	return _remove_longest(count, false)


## purge: takes off up to this many buff stacks, hots included
func remove_buffs(count: int) -> int:
	return _remove_longest(count, true)


## stat = base stat * BUFF_STAT_RATIO ^ (buffs - debuffs) for that stat
func stat_mult(which: Enums.Stat) -> float:
	var net := 0
	for stack in stacks:
		if stack.kind == EffectSpec.Kind.STAT and stack.stat == which:
			net += stack.direction
	return pow(Balance.BUFF_STAT_RATIO, net)


## every hit this unit deals gets multiplied by this, after the hit type mult
## dot ticks and heals don't use it
func damage_dealt_mult() -> float:
	return pow(Balance.BUFF_DAMAGE_RATIO, _net(EffectSpec.Kind.DAMAGE_DEALT))


## every hit this unit takes gets multiplied by this, after the hit type mult
## its dot ticks too, see _end_turn() in combat.gd
## +1 stacks mean more damage taken
func damage_taken_mult() -> float:
	return pow(Balance.BUFF_DAMAGE_RATIO, _net(EffectSpec.Kind.DAMAGE_TAKEN))


## all dot stacks together, whatever their type
func dot_stacks() -> int:
	return _count(EffectSpec.Kind.DOT)


func hot_stacks() -> int:
	return _count(EffectSpec.Kind.HOT)


## dot stacks of one type, for skills or effects that care about bleed or burn or poison
func dot_stacks_of(type: Enums.DotType) -> int:
	var count := 0
	for stack in stacks:
		if stack.kind == EffectSpec.Kind.DOT and stack.dot_type == type:
			count += 1
	return count


## runs at the end of the unit's own turn, after its cooldown is already set
## so a 1 turn speed stack still counts for the cooldown set that turn
func count_down() -> void:
	var still_on: Array[Stack] = []
	for stack in stacks:
		stack.turns_left -= 1
		if stack.turns_left > 0:
			still_on.append(stack)
	stacks = still_on


func counter(id: StringName) -> int:
	return counters.get(id, 0)


## counters never go below 0
func change_counter(id: StringName, amount: int) -> void:
	counters[id] = maxi(0, counter(id) + amount)


## short text for the screen, one entry per group, like "armor up x2 (3)"
## the number in brackets is the most turns any stack in the group has left
## later when ui is adjusted, this may become obsolete
func describe() -> Array[String]:
	var labels: Array[String] = []
	var counts: Dictionary[String, int] = {}
	var longest: Dictionary[String, int] = {}
	for stack in stacks:
		var label := _label(stack)
		if not counts.has(label):
			labels.append(label)
			counts[label] = 0
			longest[label] = 0
		counts[label] += 1
		longest[label] = maxi(longest[label], stack.turns_left)
	var lines: Array[String] = []
	for label in labels:
		lines.append("%s x%d (%d)" % [label, counts[label], longest[label]])
	for id in counters:
		if counters[id] > 0:
			lines.append("%s %d" % [id, counters[id]])
	return lines


## which stacks share a limit with this one
## a buff and a debuff of the same stat are different groups, so they never push each other out
func _group_of(stack: Stack) -> String:
	match stack.kind:
		EffectSpec.Kind.DOT:
			return "dot"
		EffectSpec.Kind.HOT:
			return "hot"
		EffectSpec.Kind.STAT:
			return "stat %d %d" % [stack.stat, stack.direction]
		_:
			return "%d %d" % [stack.kind, stack.direction]


## drops the shortest stacks left in one group until it's back at the limit
## on a tie the older stack goes first
func _trim(group: String) -> void:
	var in_group: Array[Stack] = []
	for stack in stacks:
		if _group_of(stack) == group:
			in_group.append(stack)
	while in_group.size() > Balance.EFFECT_STACK_LIMIT:
		var shortest := in_group[0]
		for stack in in_group:
			if stack.turns_left < shortest.turns_left:
				shortest = stack
		in_group.erase(shortest)
		stacks.erase(shortest)


## cleanse and purge take the longest ones left first, so they're worth the most
## on a tie the newer stack goes first
func _remove_longest(count: int, buffs: bool) -> int:
	var removed := 0
	while removed < count:
		var longest: Stack = null
		for stack in stacks:
			if is_buff(stack) == buffs and (longest == null or stack.turns_left >= longest.turns_left):
				longest = stack
		if longest == null:
			break
		stacks.erase(longest)
		removed += 1
	return removed


func _net(kind: EffectSpec.Kind) -> int:
	var net := 0
	for stack in stacks:
		if stack.kind == kind:
			net += stack.direction
	return net


func _count(kind: EffectSpec.Kind) -> int:
	var count := 0
	for stack in stacks:
		if stack.kind == kind:
			count += 1
	return count


func _label(stack: Stack) -> String:
	return label_of(stack.kind, stack.stat, stack.direction, stack.dot_type)


## a short name for an effect, like "armor up" or "bleed", for the screen and the fight log
## if the ui is changed, this may become obsolete
static func label_of(kind: EffectSpec.Kind, stat: Enums.Stat, direction: int, dot_type: Enums.DotType) -> String:
	var way := "up" if direction > 0 else "down"
	match kind:
		EffectSpec.Kind.STAT:
			return "%s %s" % [Enums.Stat.keys()[stat].to_lower(), way]
		EffectSpec.Kind.DAMAGE_DEALT:
			return "damage dealt %s" % way
		EffectSpec.Kind.DAMAGE_TAKEN:
			return "damage taken %s" % way
		EffectSpec.Kind.DOT:
			return Enums.DotType.keys()[dot_type].to_lower()
		_:
			return "regen"
