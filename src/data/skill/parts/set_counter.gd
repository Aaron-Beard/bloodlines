class_name SetCounter
extends SkillPart
## puts a named counter on the target or the user at exactly a number
## counters never go below 0, have no duration and can't be cleansed or purged
## sudden death sets its own counter, no part can touch it

## the unit this acts on
@export var who: SkillContext.Who = SkillContext.Who.TARGET

## which counter, like "mark"
@export var counter_id: StringName = &""

## formula, what the counter gets set to, rounded to a whole number
@export var value: String = "0"


## changes the counter on the real unit
func apply(context: SkillContext) -> void:
	var unit := context.unit(who)
	unit.effects.set_counter(counter_id, roundi(Formula.evaluate(value, context)))
	context.add_line("%s's %s is now %d" % [context.name_of(unit), counter_id, unit.effects.counter(counter_id)])


## like "set mark to 0 on the target"
func describe() -> String:
	return "set %s to %s on %s" % [counter_id, value, SkillContext.who_text(who)]

## true when it acts on the target
func uses_target() -> bool:
	return who == SkillContext.Who.TARGET
