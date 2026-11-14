class_name AddCounter
extends SkillPart
## adds to a named counter on the target or the user, like a combo tally or a mark
## counters never go below 0, have no duration and can't be cleansed or purged
## sudden death sets its own counter, no part can touch it

## the unit this acts on
@export var who: SkillContext.Who = SkillContext.Who.TARGET

## which counter, like "mark"
@export var counter_id: StringName = &""

## formula, how much gets added, can be negative, rounded to a whole number
@export var amount: String = "1"


## changes the counter on the real unit
func apply(context: SkillContext) -> void:
	var unit := context.unit(who)
	unit.effects.add_counter(counter_id, roundi(Formula.evaluate(amount, context)))
	context.add_line("%s's %s is now %d" % [context.name_of(unit), counter_id, unit.effects.counter(counter_id)])


## like "mark +1 on the target"
func describe() -> String:
	return "%s +%s on %s" % [counter_id, amount, SkillContext.who_text(who)]

## true when it acts on the target
func uses_target() -> bool:
	return who == SkillContext.Who.TARGET
