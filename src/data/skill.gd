class_name Skill
extends Resource
## one skill a unit can use in combat, saved as a .tres file
## skills are balanced against each other by role, and should generally not be strictly superior upgrades
## getting stronger comes from the unit's stats, so a skill you get early can still be useful even at the final tier
##
## every skill has three parameters to balance, one against each defense:
##   base_power     against armor (armor takes a smaller share out of a bigger hit)
##   base_hit_chance against dodge (more clean hits, fewer grazes)
##   cooldown_mult  against shield (more hits per stretch of time than recharge can keep up with)


@export var id: StringName = &""
@export var display_name: String = ""

## what base_power means for this skill, see SkillKind in enums
@export var kind: Enums.SkillKind = Enums.SkillKind.ATTACK

## damage for an attack, heal size for a heal, 0 for a status skill
@export var base_power: float = 0.0

## the hit chance before accuracy and dodge shift it, only rolled by attacks
## keep most below 1.0 so accuracy investment has room to matter
## it can go above 1.0 if the skill pays for it some other way, like a higher cooldown_mult
@export var base_hit_chance: float = 0.85

## multiplies the user's cooldown after using this skill
## 1.0 is normal, below 1.0 has a shorter cooldown, above 1.0 has a longer cooldown
## it never changes the speed stat, so a fast unit stays faster whatever skill it uses
@export var cooldown_mult: float = 1.0

# targeting

## which positions this skill reaches, 0 is the front
## any set of 1 to 4 positions, like just 0, 0 and 1, 2 and 3, or all four
## a skill can be used from any position, position only changes what it can reach
@export var valid_target_positions: Array[int] = [0]

## FIXED hits everyone in those positions, CHOSEN hits one unit picked from them
## attacks are usually FIXED, a CHOSEN attack is less common
## most status and heal moves are CHOSEN unless they are strictly self targeting
@export var targeting: Enums.Targeting = Enums.Targeting.FIXED

## who the skill can reach, see Reaches in enums
## SELF always hits just the user, whatever the positions and targeting say
@export var reaches: Enums.Reaches = Enums.Reaches.ENEMIES

## rare: an attack that skips the hit roll entirely, this is very uncommon
@export var unmissable: bool = false

## everything this skill does on top of its base numbers: stacks, cleanses, direct heals, its own mults and more
## each part says when it happens (its window) and can have a yes/no condition, see SkillPart
## parts in the same window happen in list order
## lifesteal is a DirectHeal part on yourself, on damage, "0.3 * damage_dealt"
@export var parts: Array[SkillPart] = []


## true if this skill is an attack
func is_attack() -> bool:
	return kind == Enums.SkillKind.ATTACK


## every attack does the double hit roll, on enemies and allies alike
## heals and status skills always land, and so do unmissable attacks
func rolls_hit_chance() -> bool:
	return is_attack() and not unmissable


## true if someone has to pick the one target, a CHOSEN skill that doesn't just hit the user
func picks_target() -> bool:
	return targeting == Enums.Targeting.CHOSEN and reaches != Enums.Reaches.SELF


## true if the skill reaches this position
func can_target_position(slot: int) -> bool:
	return valid_target_positions.has(slot)
