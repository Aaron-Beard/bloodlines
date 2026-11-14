class_name SkillContext
extends RefCounted
## everything a part or a condition gets to know about one use of a skill, at one window
## the fight fills this in and hands it over, parts never reach into the fight themselves
## the windows that run per target get one of these for each target

## which unit a part or a condition is about
enum Who { TARGET, USER }


## a frozen copy of one unit from when the window opened
## conditions and formulas read this, so every part in a window sees the same numbers, whatever order they're in
## parts still change the real unit, never the copy
class Snapshot:
	var hp: int
	var max_hp: int
	var level: int
	var position: int
	var effects: EffectTracker

	## copies what the unit looks like right now
	func _init(unit: CombatUnit, unit_position: int) -> void:
		hp = unit.hp
		max_hp = unit.max_hp()
		level = unit.level
		position = unit_position
		effects = unit.effects.copy()


var window: SkillPart.SkillWindow = SkillPart.SkillWindow.ON_USE

var user: CombatUnit
var user_snapshot: Snapshot

## null in the windows that run once per use, unless the part runs for each matching target
var target: CombatUnit
var target_snapshot: Snapshot

## the user's and the target's positions from when the targets got locked in
## every window's frozen copies use these, even after a unit goes down or someone in front of it does
var user_position: int = -1
var target_position: int = -1

## how this target's hit roll went, known from on hit on
## skills that never roll count as CLEAN
## a shield block is neither a hit nor a miss, so it's its own flag
var hit_type: Enums.HitType = Enums.HitType.CLEAN
var blocked: bool = false

## known from on damage and on heal on
var is_crit: bool = false
var target_died: bool = false

## what the skill's own hit or heal did to this target, with no overkill or overheal
## direct damage and direct heal parts never count toward these, so parts can't feed each other
var damage_dealt: int = 0
var healed: int = 0

## the same, added up over every target
var total_damage_dealt: int = 0
var total_healed: int = 0

## mult and modifier parts add their numbers in here, the fight hands them to the rolls
var mults := Damage.Mults.new()

## cooldown mult parts multiply this, the fight uses it when the cooldown gets set
var cooldown_mult: float = 1.0

## the fight's seeded rng, so a chance condition rolls the same way every time for the same seed
var rng: CombatRng

## fight log lines the parts add
var lines: Array[String] = []

## how a unit is named in the fight log, takes a CombatUnit and gives a String
## left empty, the form's display name is used
var label: Callable


## the target or the user
func unit(who: Who) -> CombatUnit:
	return target if who == Who.TARGET else user


## the frozen copy of the target or the user, null if there's no target here
func snapshot(who: Who) -> Snapshot:
	return target_snapshot if who == Who.TARGET else user_snapshot


## a unit's name for the fight log
func name_of(which: CombatUnit) -> String:
	if label.is_valid():
		return label.call(which)
	return which.form.display_name


## adds one line to the fight log, indented under the skill's own line
func add_line(text: String) -> void:
	lines.append("    " + text)


## "the target" or "yourself", for the hover text
static func who_text(who: Who) -> String:
	return "the target" if who == Who.TARGET else "yourself"
