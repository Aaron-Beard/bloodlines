class_name CombatUnit
extends RefCounted
## one creature in one fight
## the form is the species, this is the actual unit: its level, how its points are spent, its fruits and its hp
## stats are worked out from those every time they're asked for, never stored directly as a variable 
## this is so that if a stat is changed via a buff or something, the newest updated number is always used

## which global mult goes with each of the six stats
## every stat has its own, so changing one never changes another
const GLOBAL_MULT_BY_STAT: Dictionary[Enums.Stat, float] = {
	Enums.Stat.ACCURACY: Balance.GLOBAL_ACCURACY_MULT,
	Enums.Stat.ARMOR: Balance.GLOBAL_ARMOR_MULT,
	Enums.Stat.SPEED: Balance.GLOBAL_SPEED_MULT,
	Enums.Stat.DODGE: Balance.GLOBAL_DODGE_MULT,
	Enums.Stat.PEN: Balance.GLOBAL_PEN_MULT,
	Enums.Stat.SHIELD: Balance.GLOBAL_SHIELD_REGEN_MULT,
}

var form: Form
var level: int
var side: Enums.Side

## how much of the bonus pool went into offense
## the pool is zero sum, so whatever isn't here goes to defense
var spent_offense_points: int

## fruits eaten for each stat, a stat that isn't listed means 0
## counted at the unit's current level every time, so no penalty for players using them early on
var fruits: Dictionary[Enums.Stat, int] = {}

## skills picked from the form's skill pool, the EQUIPPED_SKILL_LIMIT isn't enforced yet
## later this will have a strict upper bound once units have a full moveset implemented to pick from
var equipped_skills: Array[Skill] = []

## hp is always a whole number, everything that changes it rounds once right when it's applied
## this makes the ui cleaner to display and also avoids players having like 0.2 hp left in rare cases
var hp: int

## action value left until this unit's next turn, see av_scheduler.gd
var av: float = 0.0

## shield charges right now, only a SET shield effect can put it past shield_capacity()
## each one blocks one whole hit
var shield_charges: int

## AV gone by since a charge went missing, 0 whenever the shield is full
var shield_regen_progress: float = 0.0

## every buff, debuff, dot, hot and counter on this unit
## basically any combat effect that could ever be applied is likely gonna be stored here
var effects := EffectTracker.new()


func _init(unit_form: Form, unit_level: int, unit_side: Enums.Side, offense_spent: int) -> void:
	assert(offense_spent >= 0 and offense_spent <= unit_form.bonus_pool,
		"spent offense points have to fit in the bonus pool")
	form = unit_form
	level = unit_level
	side = unit_side
	spent_offense_points = offense_spent
	hp = max_hp()
	shield_charges = form.shield_charges_at_start()


func is_alive() -> bool:
	return hp > 0


# combat points

func offense_points() -> int:
	return form.base_offense_points + spent_offense_points


func defense_points() -> int:
	return form.base_defense_points + (form.bonus_pool - spent_offense_points)


## what max HP and hit size get multiplied by from combat points
## with the ratio at 0.5 / 35: 0 points is 1.0, 35 is 1.5, 70 is 2.0
## that ratio is subject to change though for balancing purposes
## this is just the function that actually implements that constant into a stat itself
static func combat_points_multiplier(points: int) -> float:
	return 1.0 + Balance.COMBAT_POINT_RATIO * points


## what combat points add inside the six stats, already multiplied by level
## this is additive with fruit bonus and attribute bonus
static func combat_points_term(points: int, unit_level: int) -> float:
	return unit_level * Balance.COMBAT_POINT_RATIO * points


# stats

## max HP = BASE_HP_PER_LEVEL * level * combat points multiplier (defense)
## no flat part, so hp grows equivalent to damage as level increases
## rounded to the nearest whole number since hp is always whole
func max_hp() -> int:
	return roundi(Balance.BASE_HP_PER_LEVEL * level * combat_points_multiplier(defense_points()))


## how big a hit with this skill is, before armor, graze, crit or damage stacks
## hit = base_power * level * combat points multiplier (offense)
## no attribute directly scales damage
func hit_size(skill: Skill) -> float:
	return skill.base_power * level * combat_points_multiplier(offense_points())


## one of the six stats
## stat = (level * (attribute scaling + fruit bonus) + combat points term) * that stat's global mult
## then times BUFF_STAT_RATIO for every buff stack and divided by it for every debuff stack
## speed and shield regen also use this, so their stacks change cooldowns and regen
func stat(which: Enums.Stat) -> float:
	var attribute: Enums.Attribute = Enums.STAT_ATTRIBUTE[which]
	var points := offense_points() if Enums.STAT_USES_OFFENSE_POINTS[which] else defense_points()
	var fruits_eaten: int = fruits.get(which, 0)
	var attribute_scaling := form.attribute_scaling_value(attribute) \
		+ fruits_eaten * Balance.ATTRIBUTE_SCALING_PER_FRUIT
	return (level * attribute_scaling + combat_points_term(points, level)) * GLOBAL_MULT_BY_STAT[which] \
		* effects.stat_mult(which)


## no fruit part since there's no crit fruit, and no upper limit: anything above 1.0 always crits
## crit above 100% could later be considered as extra crit damage
## likely it's a better idea to just keep crits balanced to where they never reach that level
func crit_chance() -> float:
	return Balance.BASE_CRIT_CHANCE + level * (
		form.attribute_scaling_value(Enums.Attribute.PAT) * Balance.CRIT_CHANCE_PER_PAT
		+ offense_points() * Balance.CRIT_CHANCE_PER_OFFENSE_POINT)


func crit_damage_mult() -> float:
	return Balance.BASE_CRIT_DAMAGE_MULT + level * (
		form.attribute_scaling_value(Enums.Attribute.INT) * Balance.CRIT_DAMAGE_MULT_PER_INT
		+ offense_points() * Balance.CRIT_DAMAGE_MULT_PER_OFFENSE_POINT)


# turns

## AV this unit waits after a skill with cooldown_mult 1.0
## speed goes in the bottom, so twice the speed is exactly twice as many turns
func base_cooldown() -> float:
	return Balance.AV_BASE / stat(Enums.Stat.SPEED)


func cooldown_for(skill: Skill) -> float:
	return base_cooldown() * skill.cooldown_mult


# shield

## set by form's INT scaling alone, points and fruits never raise it
## points and fruits can still help scale up the regen rate of shields, just not the max stacks
## SET shields can still bypass this number
func shield_capacity() -> int:
	return form.shield_capacity()


## AV it takes to get one charge back, the shield stat works like a second, generally slower speed stat
## instead of giving a turn, in this case it gives you 1 more shield on yourself when it triggers
func av_per_shield_charge() -> float:
	return Balance.AV_BASE / stat(Enums.Stat.SHIELD)


## how long until the next charge comes back, does nothing when at full shields
func av_until_next_shield_charge() -> float:
	return av_per_shield_charge() - shield_regen_progress


## runs on every clock jump with how much AV just went by
## regen does nothing while the shield is full
## so a unit that takes a hit while at max shields will
## always wait one whole delay for it to come back
## AV per charge is worked out fresh every time, so a shield buff does speed up a charge already in progress
func regen_shield(elapsed: float) -> void:
	if shield_charges >= shield_capacity():
		shield_regen_progress = 0.0
		return
	shield_regen_progress += elapsed
	var per_charge := av_per_shield_charge()
	while shield_regen_progress >= per_charge and shield_charges < shield_capacity():
		shield_regen_progress -= per_charge
		shield_charges += 1
	if shield_charges >= shield_capacity():
		shield_regen_progress = 0.0


## a charge gets used up blocking a hit
func use_shield_charge() -> void:
	shield_charges = maxi(0, shield_charges - 1)


## a SHIELD effect: GRANT adds up to the value, SET puts it at exactly the value
## GRANT never goes past shield_capacity(), SET can
## past capacity regen just waits until charges get used back down under it
func apply_shield(mode: Enums.ShieldMode, value: int) -> void:
	if mode == Enums.ShieldMode.GRANT:
		shield_charges = maxi(shield_charges, mini(value, shield_capacity()))
	else:
		shield_charges = maxi(0, value)
	if shield_charges >= shield_capacity():
		shield_regen_progress = 0.0


# skills and hp

## every skill this unit has, whether or not anything is in reach
## signature abilities at the front of the list
func skills() -> Array[Skill]:
	var all: Array[Skill] = []
	if form.signature_attack != null:
		all.append(form.signature_attack)
	all.append_array(equipped_skills)
	return all


## all hp calculations are done as floats and then converted into an int just before it is applied, such as when damage is dealt
## anything that successfully goes through is at least 1, only nothing at all (a miss, a shield block) is 0
static func whole_hp_amount(amount: float) -> int:
	if amount <= 0.0:
		return 0
	return maxi(1, roundi(amount))


## takes hp off and returns how much actually came off
## overkill doesn't count
## useful for effects that care about the actual damage done, such as lifesteal type effects or recoil
func take_damage(amount: float) -> int:
	var removed := mini(whole_hp_amount(amount), hp)
	hp -= removed
	return removed


## puts hp back and returns how much actually went on
## never goes past max hp, and overhealing doesn't do anything
func heal(amount: float) -> int:
	var restored := mini(whole_hp_amount(amount), max_hp() - hp)
	hp += restored
	return restored
