class_name Chance
extends SkillCondition
## passes on a roll, like a 30% chance to poison
## rolls the fight's seeded rng, so the same seed always rolls the same way
## it rolls each time it's checked: once per target in the windows that run per target

## formula, the chance it passes, 0.3 for 30%
@export var chance: String = "0.5"


## rolls it
func passes(context: SkillContext) -> bool:
	return context.rng.chance(clampf(Formula.evaluate(chance, context), 0.0, 1.0))


## like "chance 0.3"
func describe() -> String:
	return "chance %s" % chance
