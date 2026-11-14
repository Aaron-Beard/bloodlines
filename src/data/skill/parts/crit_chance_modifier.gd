class_name CritChanceModifier
extends SkillPart
## adds to the user's crit chance, in percent points, so 0.1 turns 20% into 30%
## only works up to on hit, since the crit roll comes right after

## formula, the amount added, 0.1 for +10%, can be negative
@export var bonus: String = "0.0"


## adds to this target's crit chance bonus
func apply(context: SkillContext) -> void:
	context.mults.crit_chance_bonus += Formula.evaluate(bonus, context)


## like "crit chance +0.1"
func describe() -> String:
	return "crit chance +%s" % bonus
