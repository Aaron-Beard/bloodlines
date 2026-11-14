class_name AllOf
extends SkillCondition
## passes if every condition inside it does
## the inside conditions' target_rule isn't used, this one's is

@export var conditions: Array[SkillCondition] = []


## stops at the first one that doesn't pass
func passes(context: SkillContext) -> bool:
	for inner in conditions:
		if not inner.passes(context):
			return false
	return true


## about the target if any of the inside conditions is
func is_about_target() -> bool:
	for inner in conditions:
		if inner.is_about_target():
			return true
	return false


## like "(crit) and (the target died)"
func describe() -> String:
	var texts: Array[String] = []
	for inner in conditions:
		texts.append("(%s)" % inner.describe())
	return " and ".join(texts)
