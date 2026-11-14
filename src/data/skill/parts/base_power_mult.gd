class_name BasePowerMult
extends SkillPart
## multiplies the skill's base_power before armor and everything else, for hits and heals
## two of them multiply together, so x1.5 and x2 make x3
## only works up to on hit, since the hit size gets worked out right after

## formula, what base_power gets multiplied by, 1.5 means 50% more
@export var mult: String = "1.0"


## multiplies this target's power mult
func apply(context: SkillContext) -> void:
	context.mults.power_mult *= Formula.evaluate(mult, context)


## like "base power x1.5"
func describe() -> String:
	return "base power x%s" % mult
