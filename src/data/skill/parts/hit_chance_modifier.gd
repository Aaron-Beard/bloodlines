class_name HitChanceModifier
extends SkillPart
## adds to the hit chance, in percent points, so 0.05 turns 90% into 95%
## only works up to on target, since the hit roll comes right after

## formula, the amount added, 0.05 for +5%, can be negative
@export var bonus: String = "0.0"


## adds to this target's hit chance bonus
func apply(context: SkillContext) -> void:
	context.mults.hit_chance_bonus += Formula.evaluate(bonus, context)


## like "hit chance +0.05"
func describe() -> String:
	return "hit chance +%s" % bonus
