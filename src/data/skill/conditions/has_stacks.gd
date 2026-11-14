class_name HasStacks
extends SkillCondition
## passes if the unit holds at least a number of stacks of the ticked types, all of them added together

## the unit this looks at
@export var who: SkillContext.Who = SkillContext.Who.TARGET

## which stack types count, tick at least one
## each box is that type's bit, see EffectTracker.type_bit()
@export_flags("Accuracy up", "Accuracy down", "Armor up", "Armor down", "Speed up", "Speed down",
	"Dodge up", "Dodge down", "Pen up", "Pen down", "Shield up", "Shield down",
	"Damage dealt up", "Damage dealt down", "Damage taken up", "Damage taken down",
	"Bleed", "Burn", "Poison", "Regen") var types: int = 0

## formula, how many it needs at least
@export var at_least: String = "1"


## adds up the ticked types on the frozen copy
func passes(context: SkillContext) -> bool:
	var snapshot := context.snapshot(who)
	if snapshot == null:
		return false
	var total := 0
	for type in Enums.StackType.values():
		if types & EffectTracker.type_bit(type) != 0:
			total += snapshot.effects.stack_count(type)
	return total >= Formula.evaluate(at_least, context)


## like "the target has 2+ of bleed, burn"
func describe() -> String:
	return "%s has %s+ of %s" % [SkillContext.who_text(who), at_least, SkillPart.stack_types_text(types)]

## true when it looks at the target
func is_about_target() -> bool:
	return who == SkillContext.Who.TARGET
