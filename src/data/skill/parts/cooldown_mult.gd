class_name CooldownMult
extends SkillPart
## multiplies the cooldown this use of the skill sets, on top of the skill's own cooldown_mult
## works in every window, since the cooldown is only set once the skill is done

## formula, what the cooldown gets multiplied by, 0.8 is 20% shorter
@export var mult: String = "1.0"


## multiplies the cooldown mult for this use
func apply(context: SkillContext) -> void:
	context.cooldown_mult *= Formula.evaluate(mult, context)


## like "cooldown x0.8"
func describe() -> String:
	return "cooldown x%s" % mult
