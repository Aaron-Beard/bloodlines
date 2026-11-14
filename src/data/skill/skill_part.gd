class_name SkillPart
extends Resource
## one thing a skill does, like adding stacks, healing, or raising its own base power
## a skill lists its parts, and the fight checks each one when its window comes
## every kind of part is its own file with only its own settings, so a new mechanic is a new file, never a new field on Skill
## every unit using a skill shares the same loaded file, so a part never keeps anything from a fight on itself

## when a part gets checked, in the order the fight reaches them
## ON_USE and ON_RESOLUTION happen once per use, the rest happen for each target
## ON_HIT is a clean hit or a graze, a shield block is neither a hit nor a miss
## skills that never roll (heals, status skills, unmissable attacks) count as a hit on every target
## ON_DAMAGE comes right after hp comes off, ON_HEAL right after a heal goes on
## .tres files save the number, not the name, so never reorder these once content uses them
enum SkillWindow { ON_USE, ON_TARGET, ON_HIT, ON_MISS, ON_BLOCK, ON_DAMAGE, ON_HEAL, ON_RESOLUTION }

## when this part gets checked, on use unless it says otherwise
## a stack that should only land on a hit has to say on hit, nothing defaults to it
@export var window: SkillWindow = SkillWindow.ON_USE

## a yes/no check, the part only happens if it passes
## leave it empty and the part just happens when its window comes
@export var condition: SkillCondition


## does what this part does, only called once its window came and its condition passed
func apply(_context: SkillContext) -> void:
	assert(false, "every part type has its own apply()")


## what this part does in a few words, like "poison x1 for 3 turns on the target", for the hover text
func describe() -> String:
	return ""


## true if this part acts on the target, so its window has to have one
func uses_target() -> bool:
	return false


## a window's name in words, like "on hit"
static func window_name(which: SkillWindow) -> String:
	return SkillWindow.keys()[which].to_lower().replace("_", " ")


## the stack types in a set of types, in words, like "bleed, burn"
static func stack_types_text(types: int) -> String:
	var names: Array[String] = []
	for type in Enums.StackType.values():
		if types & EffectTracker.type_bit(type) != 0:
			names.append(EffectTracker.label_of(type))
	return ", ".join(names)
