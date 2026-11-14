class_name DirectHeal
extends SkillPart
## heals the target or the user for a formula's worth of raw hp
## no crit and no heal stacks of its own, only the sudden death healing loss on the unit being healed
## like every heal it rounds once and does at least 1, even when the formula works out to 0
## level or offense only count if the formula says so, like "level * 3"
## lifesteal is one of these: on yourself, on damage, "0.3 * damage_dealt"
## it never counts toward healed or total_healed, so parts can't feed each other

## the unit this acts on
@export var who: SkillContext.Who = SkillContext.Who.USER

## formula, the hp healed before sudden death
@export var amount: String = "1"


## heals the real unit
func apply(context: SkillContext) -> void:
	var unit := context.unit(who)
	var raw := Formula.evaluate(amount, context) * unit.sudden_death_healing_mult()
	var restored := unit.heal(maxi(1, CombatUnit.whole_hp_amount(raw)))
	context.add_line("%s heals %d" % [context.name_of(unit), restored])


## like "heal yourself for 0.3 * damage_dealt"
func describe() -> String:
	return "heal %s for %s" % [SkillContext.who_text(who), amount]

## true when it acts on the target
func uses_target() -> bool:
	return who == SkillContext.Who.TARGET
