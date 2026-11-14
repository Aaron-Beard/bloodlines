class_name DirectDamage
extends SkillPart
## takes a formula's worth of raw hp off the target or the user
## no hit roll, crit, armor, shield or damage dealt stacks
## the unit's damage taken stacks and sudden death still make it bigger
## like every hit it rounds once and does at least 1, even when the formula works out to 0
## level or offense only count if the formula says so, like "level * 3"
## it never counts toward damage_dealt or total_damage_dealt, so parts can't feed each other

## the unit this acts on
@export var who: SkillContext.Who = SkillContext.Who.TARGET

## formula, the hp taken off before damage taken stacks and sudden death
@export var amount: String = "1"


## takes the hp off the real unit
func apply(context: SkillContext) -> void:
	var unit := context.unit(who)
	var raw := Formula.evaluate(amount, context) \
		* unit.effects.damage_taken_mult() * unit.sudden_death_damage_taken_mult()
	var removed := unit.take_damage(maxi(1, CombatUnit.whole_hp_amount(raw)))
	context.add_line("%s takes %d" % [context.name_of(unit), removed])


## like "deal level * 3 to the target"
func describe() -> String:
	return "deal %s to %s" % [amount, SkillContext.who_text(who)]

## true when it acts on the target
func uses_target() -> bool:
	return who == SkillContext.Who.TARGET
