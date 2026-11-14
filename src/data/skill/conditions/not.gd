class_name Not
extends SkillCondition
## passes if the condition inside it doesn't
## the inside condition's target_rule isn't used, this one's is

@export var condition: SkillCondition


## the opposite of the inside condition
func passes(context: SkillContext) -> bool:
	return not condition.passes(context)


## about the target if the inside condition is
func is_about_target() -> bool:
	return condition.is_about_target()


## like "not (crit)"
func describe() -> String:
	return "not (%s)" % condition.describe()
