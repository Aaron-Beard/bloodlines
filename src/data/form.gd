class_name Form
extends Resource
## what every form has, whoever uses it: its attribute scaling and its base points
## a form is only the species, level, spent points and fruits belong to the unit, not the form
## never saved on its own: a .tres is always a PlayerForm or an EnemyForm
## PlayerForm is a species the player can own, with a tier, a bonus pool and a skill pool
## EnemyForm is for enemies only, with its points and skills written in directly
## which side a unit fights on has nothing to do with its form type, a wild player species is a PlayerForm on the enemy side
## adding a new creature should only ever mean making a new .tres, never touching existing code

@export var id: StringName = &""
@export var display_name: String = ""

## the creature's picture on the setup screen, icon.svg until real art exists
@export var image: Texture2D

# attribute scaling
# baby:         moderate x1, low x2
# intermediate: moderate x2, low x1
# final:        high x1, moderate x1, low x1
# each evolution raises one attribute a step, and never lowers an attribute to a lower step

@export var pat_attribute_scaling: Enums.AttributeScaling = Enums.AttributeScaling.LOW
@export var fer_attribute_scaling: Enums.AttributeScaling = Enums.AttributeScaling.LOW
@export var int_attribute_scaling: Enums.AttributeScaling = Enums.AttributeScaling.LOW

# combat points
# for a player form, every form of the same tier has the same base offense + base defense total
# only the split between them is different, so no form is just worse across the board

## the species' own offense points, before the player spends anything
@export var base_offense_points: int = 20

## the species' own defense points, before the player spends anything
@export var base_defense_points: int = 20


## points the player gets to spend between offense and defense, 0 for a form with no pool
func bonus_pool() -> int:
	return 0


## the skills a unit of this form always has, without taking an equipped slot, in the order they show up
func free_skills() -> Array[Skill]:
	return []


## low, moderate or high for one attribute
func attribute_scaling_for(attribute: Enums.Attribute) -> Enums.AttributeScaling:
	match attribute:
		Enums.Attribute.PAT:
			return pat_attribute_scaling
		Enums.Attribute.FER:
			return fer_attribute_scaling
		_:
			return int_attribute_scaling


## the actual number the stat formulas use, 1.0 / 1.5 / 2.0
func attribute_scaling_value(attribute: Enums.Attribute) -> float:
	return Balance.ATTRIBUTE_SCALING[attribute_scaling_for(attribute)]


## the scaling one stat uses, before fruit
## a normal form always uses the step of that stat's attribute
## EnemyForm can override this per stat
func stat_scaling(which: Enums.Stat) -> float:
	return attribute_scaling_value(Enums.STAT_ATTRIBUTE[which])


## most shield charges this form can hold, set by INT scaling alone
func shield_capacity() -> int:
	return Balance.SHIELD_CAPACITY_BY_INT[int_attribute_scaling]


## shield charges at the start of every fight, also set by INT scaling alone
func shield_charges_at_start() -> int:
	return Balance.SHIELD_CHARGES_AT_START_BY_INT[int_attribute_scaling]
