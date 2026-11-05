class_name Form
extends Resource
## one species of creature at one evolution tier, which is then saved as a .tres file
## a form is only the species: its attribute scaling, its base points and its skills
## level, spent points and fruits belong to the unit, not the form
## adding a new creature should only ever mean making a new .tres, never touching existing code

@export var id: StringName = &""
@export var display_name: String = ""

## which evolution line this form belongs to, like golem
@export var family: StringName = &""

## 0 is baby, 1 is intermediate, 2 is final
## this also indexes straight into SKILL_POOL_SIZE_BY_TIER
@export_range(0, 2) var tier: int = 0

# attribute scaling
# baby:         moderate x1, low x2
# intermediate: moderate x2, low x1
# final:        high x1, moderate x1, low x1
# each evolution raises one attribute a step, and never lowers an attribute to a lower step

@export var pat_attribute_scaling: Enums.AttributeScaling = Enums.AttributeScaling.LOW
@export var fer_attribute_scaling: Enums.AttributeScaling = Enums.AttributeScaling.LOW
@export var int_attribute_scaling: Enums.AttributeScaling = Enums.AttributeScaling.LOW

# combat points
# every form of the same tier has the same base offense + base defense total
# only the split between them is different, so no form is just worse across the board
# all three numbers are placeholders for now until the tier totals get settled later

## the species' own offense points, before the player spends anything
@export var base_offense_points: int = 10

## the species' own defense points, before the player spends anything
@export var base_defense_points: int = 15

## points the player gets to spend, always fully spent, split between offense and defense
@export var bonus_pool: int = 10

# skills

## this form's own 'free' skill, it never takes up an equipped slot
## a baby's signature attack is the one its whole line starts with
## it has to be an attack on enemies that reaches position 0, so every unit always has a move
## later forms will also inherit the signature attacks from earlier in their line, this isn't implemented yet
## doesn't count against total moves chosen
@export var signature_attack: Skill = null

## the skills a player can pick from to equip
## every form of a tier has exactly SKILL_POOL_SIZE_BY_TIER of them
## free skills are never in here, since being free and also taking a slot would be paying twice
@export var skill_pool: Array[Skill] = []


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


## most shield charges this form can hold, set by INT scaling alone
func shield_capacity() -> int:
	return Balance.SHIELD_CAPACITY_BY_INT[int_attribute_scaling]


## shield charges at the start of every fight, also set by INT scaling alone
func shield_charges_at_start() -> int:
	return Balance.SHIELD_CHARGES_AT_START_BY_INT[int_attribute_scaling]
