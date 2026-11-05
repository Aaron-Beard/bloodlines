class_name EffectSpec
extends Resource
## one effect that a skill applies, saved as data inside the skill
## skills only say which effect, how many stacks, and optionally how long
## the strength of a stack is kept in balance constants, never here
## every stack of the same effect is the same size, so "cleanse 2" always means two stacks

enum Kind {
	STAT,          ## raises or lowers one of the six stats
	DAMAGE_DEALT,  ## raises or lowers all damage the unit deals, works against every target
	DAMAGE_TAKEN,  ## raises or lowers all damage the unit takes, applied after armor
	DOT,           ## damage over time, a percent of max HP per stack per tick
	HOT,           ## heal over time, a percent of max HP per stack per tick
	CLEANSE,       ## removes debuff stacks from an ally
	PURGE,         ## removes buff stacks from an enemy
	SHIELD,        ## gives or sets shield charges
	COUNTER,       ## changes a named counter, like a combo tally. these can be used for many gameplay mechanics and effects on moves
}

@export var kind: Kind = Kind.STAT

## which stat goes up or down, only used when kind is STAT
@export var stat: Enums.Stat = Enums.Stat.ARMOR

## +1 raises the number, -1 lowers it
## used by STAT, DAMAGE_DEALT and DAMAGE_TAKEN
## careful with DAMAGE_TAKEN: +1 means the unit takes MORE damage, so a defensive effect is -1
@export_range(-1, 1, 2) var direction: int = 1

## how many stacks this effect applies at once
## a unit holds at most EFFECT_STACK_LIMIT buffs and the same number of debuffs per effect
@export var stacks: int = 1

## how many of the affected unit's own turns each stack lasts
## counts down at the end of that unit's turn, so every stack gets at least one action
## worth noting that self applied effects still count down the turn they're applied
@export var duration: int = Balance.DEFAULT_EFFECT_DURATION

## bleed, burn or poison, only used when kind is DOT
## a dot should have a type, NONE is only for everything else
@export var dot_type: Enums.DotType = Enums.DotType.NONE

## CLEANSE and PURGE: how many stacks get removed
## COUNTER: how much the counter changes by, can be negative
@export var amount: int = 0

## which counter a COUNTER effect changes
## counters have no duration and no cap, and can never be cleansed or purged
## skills that add or remove counters do so directly and specifically to that counter type
## for example a "mark" counter that can be consumed by another move for extra damage
@export var counter_id: StringName = &""

## SHIELD only: GRANT adds charges up to shield_value, SET puts them at exactly shield_value
@export var shield_mode: Enums.ShieldMode = Enums.ShieldMode.GRANT
@export var shield_value: int = 0

## true if this lands on the skill's user instead of the skill's target
## self effects execute once per use, whatever the hit result was
@export var targets_self: bool = false
