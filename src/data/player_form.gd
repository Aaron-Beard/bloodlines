class_name PlayerForm
extends Form
## a species the player can own, at one evolution tier
## the attribute tier mix, the base points total and the bonus pool all follow its tier
## a wild version of a player species is still a PlayerForm, just on the enemy side

## which evolution line this form belongs to, like golem
@export var family: StringName = &""

## 0 is baby, 1 is intermediate, 2 is final
## this also indexes straight into SKILL_POOL_SIZE_BY_TIER, BONUS_POOL_BY_TIER and BASE_POINTS_TOTAL_BY_TIER
@export_range(0, 2) var tier: int = 0

# skills

## this form's own 'free' skill, it never takes up an equipped slot
## a baby's signature attack is the one its whole line starts with
## it has to be an attack on enemies that reaches position 0, so every unit always has a move
## later forms will also inherit the signature attacks from earlier in their line, this isn't implemented yet
## doesn't count against total moves chosen
@export var signature_attack: Skill = null

## this form's free non-attack skill, like a heal or a status move, any reach and any positions
## a baby has none, intermediate and final forms each have one
## it never takes up an equipped slot and is never in the skill pool
@export var signature_skill: Skill = null

## the skills a player can pick from to equip
## every form of a tier has exactly SKILL_POOL_SIZE_BY_TIER of them
## free skills are never in here, since being free and also taking a slot would be paying twice
@export var skill_pool: Array[Skill] = []


## the tier's bonus pool, the same for every player form of that tier
func bonus_pool() -> int:
	return Balance.BONUS_POOL_BY_TIER[tier]


## the signature attack, then the signature skill, whichever of them the form has
func free_skills() -> Array[Skill]:
	var free: Array[Skill] = []
	if signature_attack != null:
		free.append(signature_attack)
	if signature_skill != null:
		free.append(signature_skill)
	return free
