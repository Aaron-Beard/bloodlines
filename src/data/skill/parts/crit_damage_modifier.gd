class_name CritDamageModifier
extends SkillPart
## adds to the user's crit damage mult, so 0.2 turns a x1.5 crit into x1.7, the same +0.2 on every unit
## only write the amount that gets added, 0.2 for +0.2, never 1.2
## only works up to on hit, since the crit roll comes right after

## formula, the amount added to the crit damage mult
@export var bonus: String = "0.0"


## adds to this target's crit damage bonus
func apply(context: SkillContext) -> void:
	context.mults.crit_damage_bonus += Formula.evaluate(bonus, context)


## like "crit damage +0.2"
func describe() -> String:
	return "crit damage +%s" % bonus
