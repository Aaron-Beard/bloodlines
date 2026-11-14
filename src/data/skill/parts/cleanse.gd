class_name Cleanse
extends SkillPart
## takes debuff stacks off the target or the user: stat downs, damage dealt down, damage taken up and the dots
## usually on allies, but it works on anyone
## the stacks with the most turns left come off first
## only ever touches stacks, never counters

## every debuff type ticked, the default for types
## each number in the checkbox list below is that type's bit, see EffectTracker.type_bit()
const ALL_TYPES := 486058

## the unit this acts on
@export var who: SkillContext.Who = SkillContext.Who.TARGET

## formula, how many stacks come off at most, rounded to a whole number
@export var count: String = "1"

## true takes every matching stack, and count isn't used
@export var take_all: bool = false

## which stack types it can take, all of them ticked to start with
@export_flags("Accuracy down:2", "Armor down:8", "Speed down:32", "Dodge down:128", "Pen down:512", "Shield down:2048", "Damage dealt down:8192", "Damage taken up:16384", "Bleed:65536", "Burn:131072", "Poison:262144") var types: int = ALL_TYPES


## takes the stacks off the real unit
func apply(context: SkillContext) -> void:
	var unit := context.unit(who)
	var most := EffectTracker.ALL if take_all else maxi(0, roundi(Formula.evaluate(count, context)))
	var removed := unit.effects.cleanse(most, types)
	context.add_line("%s gets %d stacks cleansed" % [context.name_of(unit), removed])


## like "cleanse 2 stacks from the target", plus which types if not all of them
func describe() -> String:
	var how_many := "every stack" if take_all else "%s stacks" % count
	var text := "cleanse %s from %s" % [how_many, SkillContext.who_text(who)]
	if types != ALL_TYPES:
		text += " (only %s)" % SkillPart.stack_types_text(types)
	return text

## true when it acts on the target
func uses_target() -> bool:
	return who == SkillContext.Who.TARGET
