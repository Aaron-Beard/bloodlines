class_name Enums
extends RefCounted
## shared names used everywhere in combat and content
## an enum is just named numbers: PAT is 0, FER is 1, INT is 2
## .tres files save the number, not the name, so never reorder an enum once content uses it
## only ever add new entries at the end

## the three attributes
enum Attribute { PAT, FER, INT }

## the six stats every unit gets from its attributes and points
## SHIELD means shield recharge speed, not how many charges a unit holds
enum Stat { ACCURACY, ARMOR, SPEED, DODGE, PEN, SHIELD }

## a species' scaling for one attribute
## these index straight into ATTRIBUTE_SCALING, SHIELD_CAPACITY_BY_INT
## and SHIELD_CHARGES_AT_START_BY_INT, so LOW has to stay 0 and HIGH has to stay 2
enum AttributeScaling { LOW, MODERATE, HIGH }

## what a skill's base_power means
## ATTACK: base_power is damage
## HEAL: base_power is how much it heals
## STATUS: base_power is unused and should be 0
## every kind can still apply effects on top
enum SkillKind { ATTACK, HEAL, STATUS }

## result of the double hit roll
## two successes is clean, one is a graze, zero is a miss
enum HitType { MISS, GRAZE, CLEAN }

## GRANT tops the shield up to the value but never lowers it
## SET puts it at exactly the value, even if that's lower
enum ShieldMode { GRANT, SET }

## this is just which team a unit is on
enum Side { PLAYER, ENEMY }

## FIXED hits every living unit in the skill's predetermined positions
## CHOSEN hits exactly one unit picked from them (picked at random when nobody is picking, like enemies and auto play)
## attacks are generally FIXED
enum Targeting { FIXED, CHOSEN }

## which units a skill can reach
## ENEMIES: the other team, in the skill's positions
## ALLIES: your own team in the skill's positions, yourself included
## ALLIES_NOT_SELF: your own team in the skill's positions, never yourself
## SELF: only yourself, the skill's positions and FIXED or CHOSEN don't matter
enum Reaches { ENEMIES, ALLIES, ALLIES_NOT_SELF, SELF }

## rolled with the double upgrade roll, see balance constants
enum AugmentRarity { COMMON, UNCOMMON, RARE }

## which attribute each stat is associated with
const STAT_ATTRIBUTE: Dictionary[Stat, Attribute] = {
	Stat.ACCURACY: Attribute.PAT,
	Stat.ARMOR: Attribute.PAT,
	Stat.SPEED: Attribute.FER,
	Stat.DODGE: Attribute.FER,
	Stat.PEN: Attribute.INT,
	Stat.SHIELD: Attribute.INT,
}

## true if the stat uses offense points, false if it uses defense points
const STAT_USES_OFFENSE_POINTS: Dictionary[Stat, bool] = {
	Stat.ACCURACY: true,
	Stat.ARMOR: false,
	Stat.SPEED: true,
	Stat.DODGE: false,
	Stat.PEN: true,
	Stat.SHIELD: false,
}

## every stack type a unit can hold, one name each
## a buff and a debuff of the same stat are two different types
## BLEED, BURN and POISON are the three dots, HOT is heal over time
enum StackType {
	ACCURACY_UP, ACCURACY_DOWN, ARMOR_UP, ARMOR_DOWN, SPEED_UP, SPEED_DOWN,
	DODGE_UP, DODGE_DOWN, PEN_UP, PEN_DOWN, SHIELD_UP, SHIELD_DOWN,
	DAMAGE_DEALT_UP, DAMAGE_DEALT_DOWN, DAMAGE_TAKEN_UP, DAMAGE_TAKEN_DOWN,
	BLEED, BURN, POISON, HOT,
}

## the stack type that raises each stat
const STAT_UP_STACK: Dictionary[Stat, StackType] = {
	Stat.ACCURACY: StackType.ACCURACY_UP,
	Stat.ARMOR: StackType.ARMOR_UP,
	Stat.SPEED: StackType.SPEED_UP,
	Stat.DODGE: StackType.DODGE_UP,
	Stat.PEN: StackType.PEN_UP,
	Stat.SHIELD: StackType.SHIELD_UP,
}

## the stack type that lowers each stat
const STAT_DOWN_STACK: Dictionary[Stat, StackType] = {
	Stat.ACCURACY: StackType.ACCURACY_DOWN,
	Stat.ARMOR: StackType.ARMOR_DOWN,
	Stat.SPEED: StackType.SPEED_DOWN,
	Stat.DODGE: StackType.DODGE_DOWN,
	Stat.PEN: StackType.PEN_DOWN,
	Stat.SHIELD: StackType.SHIELD_DOWN,
}
