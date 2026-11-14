class_name Crit
extends SkillCondition
## passes if the skill's hit or heal on this target crit
## crit is rolled after armor, so this is known from on damage and on heal on


## true on a crit
func passes(context: SkillContext) -> bool:
	return context.is_crit


## just "crit"
func describe() -> String:
	return "crit"

## always about the target
func is_about_target() -> bool:
	return true
