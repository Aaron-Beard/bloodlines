class_name CombatUnit
extends RefCounted
## one creature in one fight
## built fresh from the party's data (or an encounter's) when a fight starts, and thrown away when it ends
## the fight never changes the party's data, whatever needs to carry over (like hp) gets noted when it ends
## stats are worked out from their parts every time they're asked for, never stored as a variable
## so a stat changed by a buff or anything else always gives its newest number

## which global mult goes with each of the six stats
## every stat has its own, so changing one never changes another
## armor and pen also take the global base power mult, since they're measured against hit size
const GLOBAL_MULT_BY_STAT: Dictionary[Enums.Stat, float] = {
	Enums.Stat.ACCURACY: Balance.GLOBAL_ACCURACY_MULT,
	Enums.Stat.ARMOR: Balance.GLOBAL_ARMOR_MULT * Balance.GLOBAL_BASE_POWER_MULT,
	Enums.Stat.SPEED: Balance.GLOBAL_SPEED_MULT,
	Enums.Stat.DODGE: Balance.GLOBAL_DODGE_MULT,
	Enums.Stat.PEN: Balance.GLOBAL_PEN_MULT * Balance.GLOBAL_BASE_POWER_MULT,
	Enums.Stat.SHIELD: Balance.GLOBAL_SHIELD_RECHARGE_MULT,
}

var form: Form
var level: int
var side: Enums.Side

## how much of the bonus pool went into offense
## the pool is zero sum, so whatever isn't here goes to defense
var spent_offense_points: int

## fruits eaten for each stat, a stat that isn't listed means 0
## a copy of the party's numbers, counted at the unit's current level every time, so eating one early is never a waste
var fruits: Dictionary[Enums.Stat, int] = {}

## skills picked from the form's skill pool, at most EQUIPPED_SKILL_LIMIT
## a copy of the party's list, the signature attack is free and isn't in here
var equipped_skills: Array[Skill] = []

## hp is always a whole number, everything that changes it rounds once right when it's applied
var hp: int

## action value left until this unit's next turn, see av_scheduler.gd
var av: float = 0.0

## shield charges right now, only a SET shield effect can put it past shield_capacity()
## each one blocks one whole hit
var shield_charges: int

## AV gone by since a charge went missing, 0 whenever the shield is full
var shield_recharge_progress: float = 0.0

## every buff, debuff, dot, hot and counter on this unit
## a new unit gets a new, empty tracker, so nothing from an old fight can ever be on it
var effects := EffectTracker.new()

## how hard sudden death wears this unit down, 1.0 is normal
## every unit uses 1.0 for now, kept for future unit designs
var sudden_death_defense_rate: float = 1.0
var sudden_death_damage_rate: float = 1.0


## builds the unit for one fight, at full hp with the form's starting shield charges
## skills and fruits are copied in, so the fight never changes the party's own lists
## spent offense points have to fit in the form's bonus pool, and equipped skills in EQUIPPED_SKILL_LIMIT
## level has to be at least 1 and no fruit count below 0
## if one of those slips through anyway, the unit still gets built with the nearest numbers that work
## starting hp will be handed in too once the party keeps its own hp between fights
func _init(unit_form: Form, unit_level: int, unit_side: Enums.Side, offense_spent: int,
		skills_equipped: Array[Skill], fruits_eaten: Dictionary[Enums.Stat, int] = {}) -> void:
	assert(unit_level >= 1, "a unit's level has to be at least 1")
	assert(fruits_eaten.values().all(func(count: int) -> bool: return count >= 0), "fruit counts can't be below 0")
	assert(offense_spent >= 0 and offense_spent <= unit_form.bonus_pool(),
		"spent offense points have to fit in the bonus pool")
	assert(skills_equipped.size() <= Balance.EQUIPPED_SKILL_LIMIT,
		"a unit can't equip more than EQUIPPED_SKILL_LIMIT skills")
	form = unit_form
	level = fitted_level(unit_level)
	side = unit_side
	spent_offense_points = fitted_offense(offense_spent, unit_form.bonus_pool())
	equipped_skills.assign(fitted_skills(skills_equipped))
	fruits.assign(fitted_fruits(fruits_eaten))
	hp = max_hp()
	shield_charges = form.shield_charges_at_start()


## a level below 1 counts as 1
static func fitted_level(value: int) -> int:
	return maxi(1, value)


## spent offense points outside 0 to the pool count as 0
static func fitted_offense(spent: int, pool: int) -> int:
	return spent if spent >= 0 and spent <= pool else 0


## past EQUIPPED_SKILL_LIMIT only the first ones are kept
static func fitted_skills(skills_equipped: Array[Skill]) -> Array[Skill]:
	return skills_equipped.slice(0, Balance.EQUIPPED_SKILL_LIMIT)


## a fruit count below 0 counts as 0
static func fitted_fruits(fruits_eaten: Dictionary[Enums.Stat, int]) -> Dictionary[Enums.Stat, int]:
	var fitted: Dictionary[Enums.Stat, int] = {}
	for which in fruits_eaten:
		fitted[which] = maxi(0, fruits_eaten[which])
	return fitted


## true while hp is above 0
func is_alive() -> bool:
	return hp > 0


# combat points

## the form's base offense points plus the bonus pool points spent on offense
func offense_points() -> int:
	return form.base_offense_points + spent_offense_points


## the form's base defense points plus the part of the bonus pool not spent on offense
func defense_points() -> int:
	return form.base_defense_points + (form.bonus_pool() - spent_offense_points)


## what max HP and hit size get multiplied by from combat points
## with the ratio at 0.01: 0 points is 1.0, 50 is 1.5, 100 is 2.0
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


## how big a hit or heal with this much power is, before armor, graze, crit or damage stacks
## power is the skill's base power after its PowerMults, so the skill itself isn't needed here
## hit = power * level * combat points multiplier (offense) * global base power mult
## no attribute directly scales damage
func hit_size(power: float) -> float:
	return power * level * combat_points_multiplier(offense_points()) * Balance.GLOBAL_BASE_POWER_MULT


## one of the six stats
## stat = (level * (stat scaling + fruit bonus) + combat points term) * that stat's global mult
## stat scaling is the attribute's step, unless an enemy form overrides it for this one stat
## then times BUFF_STAT_RATIO for every buff stack and divided by it for every debuff stack
## speed and shield recharge also use this, so their stacks change cooldowns and recharge
## the three defense stats (armor, dodge, shield recharge) also get the sudden death defense mult
func stat(which: Enums.Stat) -> float:
	var points := offense_points() if Enums.STAT_USES_OFFENSE_POINTS[which] else defense_points()
	var fruits_eaten: int = fruits.get(which, 0)
	var scaling := form.stat_scaling(which) + fruits_eaten * Balance.ATTRIBUTE_SCALING_PER_FRUIT
	var mult := effects.stat_mult(which)
	if not Enums.STAT_USES_OFFENSE_POINTS[which]:
		mult *= sudden_death_defense_mult()
	return (level * scaling + combat_points_term(points, level)) * GLOBAL_MULT_BY_STAT[which] * mult


## how many sudden death counters this unit has, combat sets it for every living unit on a shared clock
func sudden_death_counters() -> int:
	return effects.counter(EffectTracker.SUDDEN_DEATH)


## armor, dodge and shield recharge get multiplied by this
## each counter takes SUDDEN_DEATH_DEFENSE_LOSS_PER_COUNTER of what's left, so a defense shrinks but never reaches 0
func sudden_death_defense_mult() -> float:
	var per_counter := maxf(0.0, 1.0 - Balance.SUDDEN_DEATH_DEFENSE_LOSS_PER_COUNTER * sudden_death_defense_rate)
	return pow(per_counter, sudden_death_counters())


## every hit and dot tick this unit takes gets multiplied by this, after the damage stacks
## each counter multiplies it again with no limit, so a long fight always ends
func sudden_death_damage_taken_mult() -> float:
	return pow(1.0 + Balance.SUDDEN_DEATH_DAMAGE_TAKEN_PER_COUNTER * sudden_death_damage_rate,
		sudden_death_counters())


## every heal and hot tick this unit gets is multiplied by this, never below 0
func sudden_death_healing_mult() -> float:
	return pow(maxf(0.0, 1.0 - Balance.SUDDEN_DEATH_HEALING_LOSS_PER_COUNTER), sudden_death_counters())


## the end of turn change in hp from dots and hots, plus is healing and minus is damage
## DOT_HOT_HP_PERCENT of max hp per stack, no armor or shield, never crits
## dots and hots net into one number so it only rounds once, and they cancel stack for stack
## the dot part goes up and down with damage taken stacks and sudden death, the hot part with sudden death healing loss
## damage dealt stacks don't count, since a stack doesn't know who put it on
func dot_hot_change() -> float:
	var tick := Balance.DOT_HOT_HP_PERCENT * max_hp()
	var healing := effects.stack_count(Enums.StackType.HOT) * tick * sudden_death_healing_mult()
	var damage := effects.dot_stacks() * tick * effects.damage_taken_mult() * sudden_death_damage_taken_mult()
	return healing - damage


## chance a clean hit crits: a base amount, plus the PAT attribute and offense points added per level
## no fruit part since there's no crit fruit, and no upper limit: anything above 1.0 always crits
## crit above 100% could later be considered as extra crit damage
## likely it's a better idea to just keep crits balanced to where they never reach that level
func crit_chance() -> float:
	return Balance.BASE_CRIT_CHANCE + level * (
		form.attribute_scaling_value(Enums.Attribute.PAT) * Balance.CRIT_CHANCE_PER_PAT
		+ offense_points() * Balance.CRIT_CHANCE_PER_OFFENSE_POINT)


## what a crit multiplies the hit by: a base amount, plus the INT attribute and offense points added per level
func crit_damage_mult() -> float:
	return Balance.BASE_CRIT_DAMAGE_MULT + level * (
		form.attribute_scaling_value(Enums.Attribute.INT) * Balance.CRIT_DAMAGE_MULT_PER_INT
		+ offense_points() * Balance.CRIT_DAMAGE_MULT_PER_OFFENSE_POINT)


# turns

## AV this unit waits after a skill with cooldown_mult 1.0
## speed goes in the bottom, so twice the speed is exactly twice as many turns
func base_cooldown() -> float:
	return Balance.AV_BASE / stat(Enums.Stat.SPEED)


## AV this unit waits after using this skill: its base cooldown times the skill's cooldown_mult
func cooldown_for(skill: Skill) -> float:
	return base_cooldown() * skill.cooldown_mult


# shield

## set by form's INT scaling alone, points and fruits never raise it
## points and fruits can still help scale up the recharge rate of shields, just not the max stacks
## SET shields can still bypass this number
func shield_capacity() -> int:
	return form.shield_capacity()


## AV it takes to get one charge back, the shield stat works like a second, generally slower speed stat
## instead of giving a turn, in this case it gives you 1 more shield on yourself when it triggers
func av_per_shield_charge() -> float:
	return Balance.AV_BASE / stat(Enums.Stat.SHIELD)


## how long until the next charge comes back, does nothing when at full shields
func av_until_next_shield_charge() -> float:
	return av_per_shield_charge() - shield_recharge_progress


## runs on every clock jump with how much AV just went by
## recharge does nothing while the shield is full
## so a unit that takes a hit while at max shields will
## always wait one whole delay for it to come back
## AV per charge is worked out fresh every time, so a shield buff does speed up a charge already in progress
func recharge_shield(elapsed: float) -> void:
	if shield_charges >= shield_capacity():
		shield_recharge_progress = 0.0
		return
	shield_recharge_progress += elapsed
	var per_charge := av_per_shield_charge()
	while shield_recharge_progress >= per_charge and shield_charges < shield_capacity():
		shield_recharge_progress -= per_charge
		shield_charges += 1
	if shield_charges >= shield_capacity():
		shield_recharge_progress = 0.0


## a charge gets used up blocking a hit
func use_shield_charge() -> void:
	shield_charges = maxi(0, shield_charges - 1)


## a SHIELD effect: GRANT adds up to the value, SET puts it at exactly the value
## GRANT never goes past shield_capacity(), SET can
## past capacity recharge just waits until charges get used back down under it
func apply_shield(mode: Enums.ShieldMode, value: int) -> void:
	if mode == Enums.ShieldMode.GRANT:
		shield_charges = maxi(shield_charges, mini(value, shield_capacity()))
	else:
		shield_charges = maxi(0, value)
	if shield_charges >= shield_capacity():
		shield_recharge_progress = 0.0


# skills and hp

## every skill this unit has, whether or not anything is in reach
## the form's free skills at the front of the list (signature attack, then signature skill), then the equipped ones
func skills() -> Array[Skill]:
	var all: Array[Skill] = form.free_skills()
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
## a unit that's down can't be healed, so it gives back 0
func heal(amount: float) -> int:
	if not is_alive():
		return 0
	var restored := mini(whole_hp_amount(amount), max_hp() - hp)
	hp += restored
	return restored
