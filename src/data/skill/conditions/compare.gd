class_name Compare
extends SkillCondition
## passes if one formula compares the right way with another, like target_hp less than 0.5 * target_max_hp
## it's about the target if either formula reads one of Formula.TARGET_NAMES

## formula on the left
@export var left: String = "0"

@export var comparison: SkillCondition.Comparison = SkillCondition.Comparison.LESS

## formula on the right
@export var right: String = "0"


## works out both sides and compares them
func passes(context: SkillContext) -> bool:
	return SkillCondition.compare(Formula.evaluate(left, context), comparison, Formula.evaluate(right, context))


## true if either side reads the target, matched by whole names so quoted text like user_counter("target_mark") doesn't count
func is_about_target() -> bool:
	return Formula.reads_target(left) or Formula.reads_target(right)


## like "target_hp is less than 0.5 * target_max_hp"
func describe() -> String:
	return "%s is %s %s" % [left, SkillCondition.comparison_text(comparison), right]
