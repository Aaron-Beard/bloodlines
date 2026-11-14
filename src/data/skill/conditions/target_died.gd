class_name TargetDied
extends SkillCondition
## passes if the skill's own hit took this target out
## known from on damage on, the on damage of the blow that took it out still happens


## true if the target went down from the hit
func passes(context: SkillContext) -> bool:
	return context.target_died


## just "the target died"
func describe() -> String:
	return "the target died"

## always about the target
func is_about_target() -> bool:
	return true
