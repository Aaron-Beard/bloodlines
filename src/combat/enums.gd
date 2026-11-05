class_name Enums
extends RefCounted
## shared names used everywhere in combat and content
## an enum is just named numbers: PAT is 0, FER is 1, INT is 2
## .tres files save the number, not the name, so never reorder an enum once content uses it
## only ever add new entries at the end

## the three attributes
enum Attribute { PAT, FER, INT }

## the six stats every unit gets from its attributes and points
## SHIELD means shield regen speed, not how many charges a unit holds
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

## bleed, burn and poison all work mechanically the same and share one stack limit
## the type only matters to skills that pay off on a specific type
## NONE is only for effects that aren't dots
enum DotType { NONE, BLEED, BURN, POISON }

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
