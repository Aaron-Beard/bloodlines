class_name AddShield
extends SkillPart
## adds shield charges on top of what the unit has, never past its shield capacity
## 1 charge plus 1 is 2, unless 1 was the unit's capacity
## a unit already past capacity (from a set shield) keeps what it has

## the unit this acts on
@export var who: SkillContext.Who = SkillContext.Who.USER

## formula, the number of charges, rounded to a whole number
@export var value: String = "1"


## changes the real unit's shield charges
func apply(context: SkillContext) -> void:
	var unit := context.unit(who)
	unit.apply_shield(Enums.ShieldMode.GRANT, unit.shield_charges + maxi(0, roundi(Formula.evaluate(value, context))))
	context.add_line("%s's shield is now %d" % [context.name_of(unit), unit.shield_charges])


## like "shield +1 on yourself"
func describe() -> String:
	return "shield +%s on %s" % [value, SkillContext.who_text(who)]

## true when it acts on the target
func uses_target() -> bool:
	return who == SkillContext.Who.TARGET
