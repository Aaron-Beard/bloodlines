class_name CounterCompare
extends SkillCondition
## passes if a named counter on the unit compares the right way with a formula, like "mark at least 3"

## the unit this looks at
@export var who: SkillContext.Who = SkillContext.Who.TARGET

## which counter, like "mark"
@export var counter_id: StringName = &""

@export var comparison: SkillCondition.Comparison = SkillCondition.Comparison.AT_LEAST

## formula, what the counter gets compared with
@export var value: String = "1"


## compares the counter on the frozen copy
func passes(context: SkillContext) -> bool:
	var snapshot := context.snapshot(who)
	if snapshot == null:
		return false
	return SkillCondition.compare(snapshot.effects.counter(counter_id), comparison, Formula.evaluate(value, context))


## like "the target's mark is at least 3"
func describe() -> String:
	return "%s's %s is %s %s" % [SkillContext.who_text(who), counter_id, SkillCondition.comparison_text(comparison), value]

## true when it looks at the target
func is_about_target() -> bool:
	return who == SkillContext.Who.TARGET
