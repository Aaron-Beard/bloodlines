class_name EffectTracker
extends RefCounted
## every buff, debuff, dot, hot and counter on one unit
##
## a stack only remembers its type and how many turns it has left
## how strong it is comes from balance constants, never from the stack itself or the skill that put it on
## buffs and debuffs are kept apart, up to EFFECT_STACK_LIMIT of each stack type
## one of each cancels out exactly, since a buff multiplies by the ratio and a debuff divides by it
## bleed, burn and poison all share one limit, hots have their own
## counters have no duration and no limit, and cleanse, purge and transfer never touch them
## this file only keeps track of what's on the unit, the unit itself works out what sudden death does to it
##
## the tracker never reads a skill, combat hands it plain values: which stack type, how many, how long

## stands for "no limit" as a count, and "every stack type" as a set of types
## as a set of types it works because -1 has every bit turned on
const ALL := -1

## the counter sudden death uses, set by combat on its shared clock and never counted down
const SUDDEN_DEATH := &"sudden_death"

## every stack type that is good for the unit holding it
## careful with damage taken: DOWN is the good one
const BUFFS: Array[Enums.StackType] = [
	Enums.StackType.ACCURACY_UP, Enums.StackType.ARMOR_UP, Enums.StackType.SPEED_UP,
	Enums.StackType.DODGE_UP, Enums.StackType.PEN_UP, Enums.StackType.SHIELD_UP,
	Enums.StackType.DAMAGE_DEALT_UP, Enums.StackType.DAMAGE_TAKEN_DOWN, Enums.StackType.HOT,
]

## the three dot types, they share one limit between them
const DOTS: Array[Enums.StackType] = [Enums.StackType.BLEED, Enums.StackType.BURN, Enums.StackType.POISON]


## one stack of one effect
class Stack:
	var type: Enums.StackType
	var turns_left: int
	## true if it went on during the holder's own turn, so that turn's count down skips it
	var fresh: bool = false

	## a stack of this type with this many turns left
	func _init(stack_type: Enums.StackType, turns: int, is_fresh: bool = false) -> void:
		type = stack_type
		turns_left = turns
		fresh = is_fresh


## oldest first, so on a tie the list order says which one is older
var stacks: Array[Stack] = []
var counters: Dictionary[StringName, int] = {}

## true from when the holder's turn starts until it ends, combat switches it
## a stack that goes on while this is true lasts its full count of the holder's later turns
var own_turn: bool = false


# adding and removing stacks

## adds this many stacks of one type, each lasting this many of the unit's own turns
## new stacks go on first, then the shortest ones left in the limit group get dropped until it's back at the limit
## so a fresh stack never gets thrown away in favor of one that's about to run out
## more than EFFECT_STACK_LIMIT at once would only get trimmed again, so only that many go on
func add_stacks(type: Enums.StackType, count: int, duration: int = Balance.DEFAULT_EFFECT_DURATION) -> void:
	assert(count >= 0 and duration >= 1, "stacks need a count of 0 or more and at least 1 turn")
	count = mini(count, Balance.EFFECT_STACK_LIMIT)
	for i in count:
		stacks.append(Stack.new(type, duration, own_turn))
	_trim(type)


## cleanse: takes off up to count debuff stacks (ALL for every one), dots included
## types picks which stack types it can take, ALL for every type, buff types in it are just skipped
## returns how many came off
func cleanse(count: int, types: int = ALL) -> int:
	return _take(count, types, false).size()


## purge: takes off up to count buff stacks (ALL for every one), hots included
## types works the same as for cleanse, debuff types in it are just skipped
func purge(count: int, types: int = ALL) -> int:
	return _take(count, types, true).size()


## moves up to most stacks of one type (ALL for every one) onto another unit, keeping their turns left
## the ones with the most turns left go first, same as cleanse and purge
## they always come off this unit, even the ones that don't fit the other unit's limit
## returns how many came off this unit
func transfer(type: Enums.StackType, most: int, destination: EffectTracker) -> int:
	assert(destination != self, "a transfer needs two different units")
	var moved := _take(most, type_bit(type), is_buff_type(type))
	for stack in moved:
		destination.stacks.append(Stack.new(stack.type, stack.turns_left, destination.own_turn))
	destination._trim(type)
	return moved.size()


## runs at the end of the unit's own turn, after its cooldown is already set
## so a 1 turn speed stack still counts for the cooldown set that turn
## a stack that went on during this same turn is skipped once, so a stack always lasts its full count of later turns
func count_down() -> void:
	var still_on: Array[Stack] = []
	for stack in stacks:
		if stack.fresh:
			stack.fresh = false
			still_on.append(stack)
			continue
		stack.turns_left -= 1
		if stack.turns_left > 0:
			still_on.append(stack)
	stacks = still_on


# reading stacks

## how many stacks of one type are on the unit
func stack_count(type: Enums.StackType) -> int:
	var count := 0
	for stack in stacks:
		if stack.type == type:
			count += 1
	return count


## all dot stacks together, whatever their type
func dot_stacks() -> int:
	var count := 0
	for type in DOTS:
		count += stack_count(type)
	return count


## stat = base stat * BUFF_STAT_RATIO ^ (ups - downs) for that stat
func stat_mult(which: Enums.Stat) -> float:
	return pow(Balance.BUFF_STAT_RATIO,
		stack_count(Enums.STAT_UP_STACK[which]) - stack_count(Enums.STAT_DOWN_STACK[which]))


## every hit this unit deals gets multiplied by this, after the hit type mult
## dot ticks and heals don't use it
func damage_dealt_mult() -> float:
	return pow(Balance.BUFF_DAMAGE_RATIO,
		stack_count(Enums.StackType.DAMAGE_DEALT_UP) - stack_count(Enums.StackType.DAMAGE_DEALT_DOWN))


## every hit this unit takes gets multiplied by this, after the hit type mult, and its dot ticks too
## up stacks mean more damage taken
func damage_taken_mult() -> float:
	return pow(Balance.BUFF_DAMAGE_RATIO,
		stack_count(Enums.StackType.DAMAGE_TAKEN_UP) - stack_count(Enums.StackType.DAMAGE_TAKEN_DOWN))


# counters

## the counter's current number, 0 if it was never set
func counter(id: StringName) -> int:
	return counters.get(id, 0)


## adds to a counter, amount can be negative, counters never go below 0
func add_counter(id: StringName, amount: int) -> void:
	counters[id] = maxi(0, counter(id) + amount)


## puts a counter at exactly this number, never below 0
func set_counter(id: StringName, value: int) -> void:
	counters[id] = maxi(0, value)


# snapshots

## a frozen copy of every stack and counter right now
## a window's conditions and formulas read this, so stacks added partway through the window don't change them
## changing the copy never changes the unit, and the other way round
func copy() -> EffectTracker:
	var frozen := EffectTracker.new()
	for stack in stacks:
		frozen.stacks.append(Stack.new(stack.type, stack.turns_left))
	frozen.counters = counters.duplicate()
	return frozen


# stack types

## true for anything good for the unit holding it
static func is_buff_type(type: Enums.StackType) -> bool:
	return type in BUFFS


## the bit for one stack type in a set of types, for cleanse and purge
## join several with |, like type_bit(BLEED) | type_bit(BURN)
static func type_bit(type: Enums.StackType) -> int:
	return 1 << type


## a short name for a stack type, like "armor up" or "bleed", for the screen and the fight log
## if the ui is changed, this may become obsolete
static func label_of(type: Enums.StackType) -> String:
	if type == Enums.StackType.HOT:
		return "regen"
	return Enums.StackType.keys()[type].to_lower().replace("_", " ")


## short text for the screen, one entry per stack type, like "armor up x2 (3)"
## the number in brackets is the most turns any stack of that type has left
## later when ui is adjusted, this may become obsolete
func describe() -> Array[String]:
	var types: Array[Enums.StackType] = []
	var counts: Dictionary[Enums.StackType, int] = {}
	var longest: Dictionary[Enums.StackType, int] = {}
	for stack in stacks:
		if not counts.has(stack.type):
			types.append(stack.type)
			counts[stack.type] = 0
			longest[stack.type] = 0
		counts[stack.type] += 1
		longest[stack.type] = maxi(longest[stack.type], stack.turns_left)
	var lines: Array[String] = []
	for type in types:
		lines.append("%s x%d (%d)" % [label_of(type), counts[type], longest[type]])
	for id in counters:
		if counters[id] > 0:
			lines.append("%s %d" % [id, counters[id]])
	return lines


# inside

## the stack types that share a limit with this one
## a buff and a debuff of the same stat are different types, so they never push each other out
func _limit_group(type: Enums.StackType) -> Array[Enums.StackType]:
	if type in DOTS:
		return DOTS
	return [type]


## drops the shortest stacks left in one limit group until it's back at the limit
## on a tie the older stack goes first
func _trim(type: Enums.StackType) -> void:
	var group := _limit_group(type)
	var in_group: Array[Stack] = []
	for stack in stacks:
		if stack.type in group:
			in_group.append(stack)
	while in_group.size() > Balance.EFFECT_STACK_LIMIT:
		var shortest := in_group[0]
		for stack in in_group:
			if stack.turns_left < shortest.turns_left:
				shortest = stack
		in_group.erase(shortest)
		stacks.erase(shortest)


## takes off up to count stacks that are buffs (or debuffs) and whose type is in types, and returns them
## the most turns left go first, so they're worth the most, on a tie the newer stack goes first
func _take(count: int, types: int, buffs: bool) -> Array[Stack]:
	var taken: Array[Stack] = []
	while count == ALL or taken.size() < count:
		var longest: Stack = null
		for stack in stacks:
			if is_buff_type(stack.type) == buffs and types & type_bit(stack.type) != 0 \
					and (longest == null or stack.turns_left >= longest.turns_left):
				longest = stack
		if longest == null:
			break
		stacks.erase(longest)
		taken.append(longest)
	return taken
