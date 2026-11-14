class_name SetShield
extends SkillPart
## puts the shield at exactly a number of charges, this one can go past capacity
## past capacity, recharge just waits until charges get used back down under it

## the unit this acts on
@export var who: SkillContext.Who = SkillContext.Who.USER

## formula, the number of charges, rounded to a whole number
@export var value: String = "1"


## changes the real unit's shield charges
func apply(context: SkillContext) -> void:
	var unit := context.unit(who)
	unit.apply_shield(Enums.ShieldMode.SET, maxi(0, roundi(Formula.evaluate(value, context))))
	context.add_line("%s's shield is now %d" % [context.name_of(unit), unit.shield_charges])


## like "set shield to 3 on yourself"
func describe() -> String:
	return "set shield to %s on %s" % [value, SkillContext.who_text(who)]

## true when it acts on the target
func uses_target() -> bool:
	return who == SkillContext.Who.TARGET
