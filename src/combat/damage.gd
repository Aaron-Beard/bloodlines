class_name Damage
extends RefCounted
## the damage steps for one attack on one target
##   1. hit roll: miss, graze or clean hit (heals, status skills and unmissable attacks skip it)
##   2. shield: if the target has a charge, it blocks the whole hit and nothing below happens
##   3. armor curve: damage = hit * hit / (hit + armor left), this looks weird, see balance constants for why
##   4. crit roll, only on a clean hit, so a graze can never crit
##   5. hit type mult: graze mult, crit mult or 1.0, never two of them
##   6. damage stacks: the attacker's damage dealt mult and the defender's damage taken mult
## the order matters and getting it backwards still probably runs fine, it's just potentially silently doing the math not in the intended way
## the shield comes after the hit roll, so a miss never uses a charge and dodge and shield stack
## the shield comes before armor, so armor never also applies to a blocked hit
## armor comes before graze and crit, so armor takes the same share out of a crit or a graze as out of a normal hit
## damage stacks come after armor, so a stack is worth exactly its ratio whatever the target's armor
## later: sudden death multiplies in at the very end, after the damage stacks
## technically all the stuff after armor is multiplicative so changing their order wouldn't break anything
## the current order for those is just chosen based on logical expectations of what you'd think would be the way to go through it generally


## what one attack did, combat reads this and applies it
class AttackResult:
	var hit_type: Enums.HitType = Enums.HitType.MISS
	var is_crit: bool = false
	## true if the target's shield took the hit, combat uses up the charge
	var blocked: bool = false
	var damage: float = 0.0


## hit chance for one attacker against one defender with one skill
## final hit chance = base_hit_chance + (accuracy - dodge) / average level * HIT_CHANCE_PER_ACCURACY_DODGE_GAP
## dividing by average level gives a bit of advantage to the higher level unit when they are uneven
## it also keeps things relatively equal in how they scale as level increases
static func final_hit_chance(attacker: CombatUnit, defender: CombatUnit, skill: Skill) -> float:
	var average_level := (attacker.level + defender.level) / 2.0
	var gap := attacker.stat(Enums.Stat.ACCURACY) - defender.stat(Enums.Stat.DODGE)
	var hit_chance := skill.base_hit_chance + gap / average_level * Balance.HIT_CHANCE_PER_ACCURACY_DODGE_GAP
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


## exactly one of graze mult, crit mult or 1.0
## if other hit types or multipliers are later added, they would fit here
static func hit_type_mult(hit_type: Enums.HitType, is_crit: bool, crit_damage_mult: float) -> float:
	if hit_type == Enums.HitType.GRAZE:
		return Balance.GRAZE_DAMAGE_MULT
	if is_crit:
		return crit_damage_mult
	return 1.0


## one attack on one target, start to finish
## this only works out what happens, it never changes anyone's hp, the combat functions do that
static func resolve(attacker: CombatUnit, defender: CombatUnit, skill: Skill, rng: CombatRng) -> AttackResult:
	var result := AttackResult.new()

	if skill.rolls_hit_chance():
		result.hit_type = roll_hit_type(final_hit_chance(attacker, defender, skill), rng)
	else:
		# unmissable attacks count as a clean hit, so they can still crit
		result.hit_type = Enums.HitType.CLEAN
	if result.hit_type == Enums.HitType.MISS:
		return result

	# a graze uses a whole charge too, and unmissable attacks still get blocked
	if defender.shield_charges > 0:
		result.blocked = true
		return result

	var remaining := armor_left(defender.stat(Enums.Stat.ARMOR), attacker.stat(Enums.Stat.PEN))
	var damage := after_armor(attacker.hit_size(skill), remaining)

	# everything after armor happens together from here
	# armor doesn't use the rng at all, so rolling crit here instead of before armor gives the exact same fights
	if result.hit_type == Enums.HitType.CLEAN:
		result.is_crit = rng.chance(attacker.crit_chance())
	result.damage = damage * hit_type_mult(result.hit_type, result.is_crit, attacker.crit_damage_mult()) \
		* attacker.effects.damage_dealt_mult() * defender.effects.damage_taken_mult()
	return result


## how much a HEAL skill heals one target, and whether it crit
## same formula as a hit but with no armor, dodge or shield: just hit size and the crit roll
## damage dealt and damage taken stacks don't change heals, a healing received stack could come later
## sudden death healing loss will multiply in here later if implemented
static func resolve_heal(healer: CombatUnit, skill: Skill, rng: CombatRng) -> AttackResult:
	var result := AttackResult.new()
	result.hit_type = Enums.HitType.CLEAN
	result.is_crit = rng.chance(healer.crit_chance())
	result.damage = healer.hit_size(skill) * (healer.crit_damage_mult() if result.is_crit else 1.0)
	return result
