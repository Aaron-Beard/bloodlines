class_name Formula
extends RefCounted
## works out the number in a formula box, a bit of math text like "0.3 * damage_dealt" or "level * 3"
## a formula is only for working out a number, nothing else
## a plain number like "2" is a formula too
## it reads the frozen copies of the units, so every part in a window gets the same answer
## only the names listed here can be used, any other name could break the seeded rng (randf() for example)

## numbers a formula can read
## target_hp and target_max_hp are 0 where there's no target
## damage_dealt and healed are this target's, total_damage_dealt and total_healed are every target's added up
const INPUTS: PackedStringArray = [
	"user_hp", "user_max_hp", "level", "target_hp", "target_max_hp",
	"damage_dealt", "healed", "total_damage_dealt", "total_healed",
]

## functions a formula can call
## min, max, clamp, abs, floor and ceil come with godot, the rest are in Scope below
const CALLS: PackedStringArray = [
	"min", "max", "clamp", "abs", "floor", "ceil",
	"hit_size", "user_counter", "target_counter", "user_stacks", "target_stacks",
]

## the names that make a formula about the target
## damage_dealt and healed count too, since they're what the skill did to one target
const TARGET_NAMES: PackedStringArray = [
	"target_hp", "target_max_hp", "target_counter", "target_stacks", "damage_dealt", "healed",
]

## other names a formula can use for a stack type, by what the screen calls it
const STACK_NAME_ALIASES: Dictionary[String, Enums.StackType] = {
	"regen": Enums.StackType.HOT,
}


## every name in a formula, with numbers and "quoted text" taken out first
static func names_in(text: String) -> Array[String]:
	var bare := RegEx.create_from_string("\"[^\"]*\"").sub(text, "", true)
	bare = RegEx.create_from_string("\\b\\d[\\d.]*([eE][-+]?\\d+)?").sub(bare, "", true)
	var names: Array[String] = []
	for found in RegEx.create_from_string("[A-Za-z_]\\w*").search_all(bare):
		if not names.has(found.get_string()):
			names.append(found.get_string())
	return names


## true if the formula reads any of TARGET_NAMES
static func reads_target(text: String) -> bool:
	for name in names_in(text):
		if name in TARGET_NAMES:
			return true
	return false


## the functions a formula can call that read a unit
class Scope:
	var context: SkillContext
	## what went wrong, like a stack type that doesn't exist, empty if nothing did
	var problem: String = ""

	## keeps the context the formula is worked out for
	func _init(for_context: SkillContext) -> void:
		context = for_context

	## the user's hit size for this much power, see CombatUnit.hit_size()
	func hit_size(power: float) -> float:
		return context.user.hit_size(power)

	## a counter on the user, like user_counter("mark")
	func user_counter(id: String) -> float:
		return _counter(context.user_snapshot, id)

	## a counter on the target, 0 with no target
	func target_counter(id: String) -> float:
		return _counter(context.target_snapshot, id)

	## how many stacks of one type the user holds, by its name in lowercase, like user_stacks("armor_up")
	func user_stacks(type_name: String) -> float:
		return _stacks(context.user_snapshot, type_name)

	## how many stacks of one type the target holds, like target_stacks("poison"), 0 with no target
	func target_stacks(type_name: String) -> float:
		return _stacks(context.target_snapshot, type_name)

	## reads a counter from a frozen copy
	func _counter(snapshot: SkillContext.Snapshot, id: String) -> float:
		if snapshot == null:
			return 0.0
		return float(snapshot.effects.counter(StringName(id)))

	## reads a stack count from a frozen copy, and notes it if the type name doesn't exist
	## "regen" works as well as "hot", see STACK_NAME_ALIASES
	func _stacks(snapshot: SkillContext.Snapshot, type_name: String) -> float:
		var index: int = Formula.STACK_NAME_ALIASES.get(type_name.to_lower(), -1)
		if index == -1:
			index = Enums.StackType.keys().find(type_name.to_upper())
		if index == -1:
			problem = "there's no stack type called \"%s\"" % type_name
			return 0.0
		if snapshot == null:
			return 0.0
		return float(snapshot.effects.stack_count(index as Enums.StackType))


## a worked out formula: its number, or what went wrong
class Outcome:
	var value: float = 0.0
	var problem: String = ""


## works out the formula for this context, 0 if it can't be worked out
static func evaluate(text: String, context: SkillContext) -> float:
	var outcome := run(text, context)
	if outcome.problem != "":
		push_error(outcome.problem)
	return outcome.value


## works out the formula and says what went wrong, if anything did
static func run(text: String, context: SkillContext) -> Outcome:
	var outcome := Outcome.new()
	var expression := Expression.new()
	if expression.parse(text, INPUTS) != OK:
		outcome.problem = "\"%s\" isn't a formula: %s" % [text, expression.get_error_text()]
		return outcome
	var scope := Scope.new(context)
	var result: Variant = expression.execute(_input_values(context), scope, false)
	if expression.has_execute_failed():
		outcome.problem = "\"%s\" couldn't be worked out: %s" % [text, expression.get_error_text()]
	elif scope.problem != "":
		outcome.problem = "\"%s\": %s" % [text, scope.problem]
	elif not (result is float or result is int):
		outcome.problem = "\"%s\" doesn't give a number" % text
	elif not is_finite(float(result)):
		outcome.problem = "\"%s\" doesn't give a real number" % text
	else:
		outcome.value = float(result)
	return outcome


## the input numbers in the same order as INPUTS
## all of them are decimals, so damage_dealt / 4 with 10 damage is 2.5 and not 2
static func _input_values(context: SkillContext) -> Array:
	var user := context.user_snapshot
	var target := context.target_snapshot
	return [
		float(user.hp), float(user.max_hp), float(user.level),
		float(target.hp) if target != null else 0.0,
		float(target.max_hp) if target != null else 0.0,
		float(context.damage_dealt), float(context.healed),
		float(context.total_damage_dealt), float(context.total_healed),
	]
