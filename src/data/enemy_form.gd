class_name EnemyForm
extends Form
## a form for enemies only, so it isn't held to the rules player forms follow
## no tier: the tier rules for attribute steps don't apply here, any mix of low/moderate/high is fine
## no bonus pool: base offense and defense points are written in directly
## no signature skills and no skill pool: it has one fixed skill list, with no limit on how many
## on top of that, each stat can be given its own scaling number instead of its attribute's step
## an override only counts while its box is ticked, unticked falls back to how a normal form works

## every skill a unit of this form has, all of them free, none of them take an equipped slot
@export var fixed_skills: Array[Skill] = []

@export_group("stat scaling overrides")
## each one replaces the attribute step for that one stat only, like 2.6 dodge on a boss
## the number is used in the same place as 1.0 / 1.5 / 2.0 would be, so fruit still adds on top
@export var override_accuracy: bool = false
@export var accuracy_scaling: float = 1.0
@export var override_armor: bool = false
@export var armor_scaling: float = 1.0
@export var override_speed: bool = false
@export var speed_scaling: float = 1.0
@export var override_dodge: bool = false
@export var dodge_scaling: float = 1.0
@export var override_pen: bool = false
@export var pen_scaling: float = 1.0
@export var override_shield_recharge: bool = false
@export var shield_recharge_scaling: float = 1.0

@export_group("shield overrides")
## replaces the INT step's shield capacity while ticked
@export var override_shield_capacity: bool = false
@export var shield_capacity_count: int = 1
## replaces the INT step's starting shield charges while ticked
@export var override_shield_charges_at_start: bool = false
@export var shield_charges_at_start_count: int = 0


## the ticked override for this stat, or its attribute's step when unticked
func stat_scaling(which: Enums.Stat) -> float:
	match which:
		Enums.Stat.ACCURACY:
			return accuracy_scaling if override_accuracy else super(which)
		Enums.Stat.ARMOR:
			return armor_scaling if override_armor else super(which)
		Enums.Stat.SPEED:
			return speed_scaling if override_speed else super(which)
		Enums.Stat.DODGE:
			return dodge_scaling if override_dodge else super(which)
		Enums.Stat.PEN:
			return pen_scaling if override_pen else super(which)
		_:
			return shield_recharge_scaling if override_shield_recharge else super(which)


## the ticked shield capacity, or the INT step's when unticked
func shield_capacity() -> int:
	return shield_capacity_count if override_shield_capacity else super()


## the ticked starting charges, or the INT step's when unticked
func shield_charges_at_start() -> int:
	return shield_charges_at_start_count if override_shield_charges_at_start else super()


## the fixed skill list, in its own order
func free_skills() -> Array[Skill]:
	return fixed_skills.duplicate()
