class_name AddStack
extends SkillPart
## puts stacks of one type on the target or the user
## how strong a stack is lives in balance constants, here it's only which type, how many and how long

## the unit this acts on
@export var who: SkillContext.Who = SkillContext.Who.TARGET

@export var stack_type: Enums.StackType = Enums.StackType.ARMOR_UP

## formula, how many stacks go on, rounded to a whole number
@export var count: String = "1"

## formula, how many of the unit's own turns each stack lasts, rounded, at least 1
@export var duration: String = str(Balance.DEFAULT_EFFECT_DURATION)


## adds the stacks to the real unit
func apply(context: SkillContext) -> void:
	var unit := context.unit(who)
	var how_many := maxi(0, roundi(Formula.evaluate(count, context)))
	var turns := maxi(1, roundi(Formula.evaluate(duration, context)))
	unit.effects.add_stacks(stack_type, how_many, turns)
	context.add_line("%s gets %s x%d for %d turns" % [
		context.name_of(unit), EffectTracker.label_of(stack_type), how_many, turns])


## like "poison x1 for 3 turns on the target"
func describe() -> String:
	return "%s x%s for %s turns on %s" % [
		EffectTracker.label_of(stack_type), count, duration, SkillContext.who_text(who)]

## true when it acts on the target
func uses_target() -> bool:
	return who == SkillContext.Who.TARGET
