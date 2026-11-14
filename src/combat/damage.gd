class_name Damage
extends RefCounted
## the damage steps for one attack on one target, split into three stages so combat can run the skill's windows in between
##   stage 1, roll_hit(): miss, graze or clean hit (heals, status skills and unmissable attacks skip it and count as clean)
##   stage 2, is_blocked(): if the target has a shield charge, it blocks the whole hit and stage 3 never happens
##   stage 3, land():
##     armor curve: damage = hit * hit / (hit + armor left), this looks weird, see balance constants for why
##     crit roll, only on a clean hit, so a graze can never crit
##     hit type mult: graze mult, crit mult or 1.0, never two of them
##     damage stacks: the attacker's damage dealt mult and the defender's damage taken mult
##     sudden death: the defender's sudden death damage taken mult, last
## heals have their own stage, heal_amount(): hit size, the crit roll and the target's sudden death healing mult
## the order matters and getting it backwards still probably runs fine, it's just potentially silently doing the math not in the intended way
## the shield comes after the hit roll, so a miss never uses a charge and dodge and shield stack
## the shield comes before armor, so armor never also applies to a blocked hit
## armor comes before graze and crit, so armor takes the same share out of a crit or a graze as out of a normal hit
## damage stacks come after armor, so a stack is worth exactly its ratio whatever the target's armor
## technically all the stuff after armor is multiplicative so changing their order wouldn't break anything
## the current order for those is just chosen based on logical expectations of what you'd think would be the way to go through it generally
##
## a skill's own mults (PowerMult, HitChanceModifier, CritChanceModifier, CritDamageModifier) come in already worked out, in a Mults
## combat decides which of the skill's parts count, since only combat knows which window is open and what the snapshot says
## so this file never looks at a skill's parts itself, it just does the math with the numbers it's given


## the skill's own mults for one use on one target
## a new one changes nothing, so a skill with no parts just passes Mults.new()
## the chances and crit damage add on (0.05 is +5%), power multiplies
class Mults:
	## multiplies base_power before armor and everything else, for hits and heals
	var power_mult: float = 1.0
	## added to the hit chance before the clamps
	var hit_chance_bonus: float = 0.0
	## added to the user's crit chance
	var crit_chance_bonus: float = 0.0
	## added to the user's crit damage mult, so 1.5 with 0.2 here crits for 1.7, the same +0.2 on every unit
	## only write the amount that gets added, 0.2 for +0.2, never 1.2
	var crit_damage_bonus: float = 0.0

	## a new Mults with the same numbers, so changing one target's mults never changes another's
	func copy() -> Mults:
		var other := Mults.new()
		other.power_mult = power_mult
		other.hit_chance_bonus = hit_chance_bonus
		other.crit_chance_bonus = crit_chance_bonus
		other.crit_damage_bonus = crit_damage_bonus
		return other


## what a hit or heal works out to before it's rounded, combat applies it
class Result:
	var is_crit: bool = false
	## damage for a hit, healing for a heal, still a decimal
	var amount: float = 0.0


# stage 1: hit roll

## hit chance for one attacker against one defender with one skill
## final hit chance = base_hit_chance + hit chance bonus + (accuracy - dodge) / average level * HIT_CHANCE_PER_ACCURACY_DODGE_GAP
## dividing by average level gives a bit of advantage to the higher level unit when they are uneven
## it also keeps things relatively equal in how they scale as level increases
static func final_hit_chance(attacker: CombatUnit, defender: CombatUnit, skill: Skill, mults: Mults) -> float:
	var average_level := (attacker.level + defender.level) / 2.0
	var gap := attacker.stat(Enums.Stat.ACCURACY) - defender.stat(Enums.Stat.DODGE)
	var hit_chance := skill.base_hit_chance + mults.hit_chance_bonus \
		+ gap / average_level * Balance.HIT_CHANCE_PER_ACCURACY_DODGE_GAP
	return clampf(hit_chance, Balance.FINAL_HIT_CHANCE_MIN, Balance.FINAL_HIT_CHANCE_MAX)


## rolls the hit chance twice: two successes is a clean hit, one is a graze, zero is a miss
static func roll_hit_type(hit_chance: float, rng: CombatRng) -> Enums.HitType:
	var successes := 0
	if rng.chance(hit_chance):
		successes += 1
	if rng.chance(hit_chance):
		successes += 1
	match successes:
		2:
			return Enums.HitType.CLEAN
		1:
			return Enums.HitType.GRAZE
		_:
			return Enums.HitType.MISS


## stage 1 for one target: a skill that doesn't roll counts as a clean hit, so an unmissable attack can still crit
static func roll_hit(attacker: CombatUnit, defender: CombatUnit, skill: Skill, mults: Mults, rng: CombatRng) -> Enums.HitType:
	if not skill.rolls_hit_chance():
		return Enums.HitType.CLEAN
	return roll_hit_type(final_hit_chance(attacker, defender, skill, mults), rng)


# stage 2: shield

## true if the defender's shield takes the whole hit, combat uses up the charge
## only asked about a clean hit or a graze, a miss never reaches the shield
## a graze uses a whole charge too, and unmissable attacks still get blocked
static func is_blocked(defender: CombatUnit) -> bool:
	return defender.shield_charges > 0


# stage 3: armor, crit and the mults

## armor minus pen, never below 0
## pen past the armor is just wasted, it never turns into extra damage
static func armor_left(armor: float, pen: float) -> float:
	return maxf(0.0, armor - pen)


## the armor curve: damage = hit * hit / (hit + armor left)
## armor always reduces some damage, but never all damage
## when hit and armor left after pen are equal it takes exactly half the damage off,
## and the bigger the hit is in comparison to the armor, the smaller the share armor takes
## and vice versa
static func after_armor(hit: float, armor_remaining: float) -> float:
	if hit <= 0.0:
		return 0.0
	return hit * hit / (hit + armor_remaining)


## rolls whether a clean hit or a heal crits, with the skill's crit chance bonus added on
static func roll_crit(user: CombatUnit, mults: Mults, rng: CombatRng) -> bool:
	return rng.chance(user.crit_chance() + mults.crit_chance_bonus)


## what a crit multiplies by: the user's crit damage mult plus the skill's bonus
static func crit_mult(user: CombatUnit, mults: Mults) -> float:
	return user.crit_damage_mult() + mults.crit_damage_bonus


## exactly one of graze mult, crit mult or 1.0
## if other hit types or multipliers are later added, they would fit here
static func hit_type_mult(hit_type: Enums.HitType, is_crit: bool, crit_damage_mult: float) -> float:
	if hit_type == Enums.HitType.GRAZE:
		return Balance.GRAZE_DAMAGE_MULT
	if is_crit:
		return crit_damage_mult
	return 1.0


## stage 3 for one target: how much a clean hit or graze that got past the shield does
## this only works out the number, it never changes anyone's hp, combat does that
static func land(attacker: CombatUnit, defender: CombatUnit, skill: Skill, hit_type: Enums.HitType,
		mults: Mults, rng: CombatRng) -> Result:
	var result := Result.new()
	var hit := attacker.hit_size(skill.base_power * mults.power_mult)
	var damage := after_armor(hit, armor_left(defender.stat(Enums.Stat.ARMOR), attacker.stat(Enums.Stat.PEN)))

	# everything after armor happens together from here
	# armor doesn't use the rng at all, so rolling crit here instead of before armor gives the exact same fights
	if hit_type == Enums.HitType.CLEAN:
		result.is_crit = roll_crit(attacker, mults, rng)
	result.amount = damage * hit_type_mult(hit_type, result.is_crit, crit_mult(attacker, mults)) \
		* attacker.effects.damage_dealt_mult() * defender.effects.damage_taken_mult() \
		* defender.sudden_death_damage_taken_mult()
	return result


# heals

## how much a HEAL skill heals one target, and whether it crit
## same formula as a hit but with no armor, dodge or shield: just hit size and the crit roll
## damage dealt and damage taken stacks don't change heals, a healing received stack could come later
## then the target's sudden death healing mult, since healing loss is on the unit being healed
static func heal_amount(healer: CombatUnit, target: CombatUnit, skill: Skill, mults: Mults, rng: CombatRng) -> Result:
	var result := Result.new()
	result.is_crit = roll_crit(healer, mults, rng)
	result.amount = healer.hit_size(skill.base_power * mults.power_mult) \
		* (crit_mult(healer, mults) if result.is_crit else 1.0) * target.sudden_death_healing_mult()
	return result
