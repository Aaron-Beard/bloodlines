class_name TransferStack
extends SkillPart
## moves stacks of one type between the user and the target, keeping their turns left
## the stacks with the most turns left go first
## they always come off the source, even the ones that don't fit the destination's limit
## works on any stack type, so a unit can bleed itself and pass the bleeds on

@export var stack_type: Enums.StackType = Enums.StackType.BLEED

## formula, how many stacks move at most, rounded to a whole number
@export var most: String = "1"

## true moves every stack of the type, and most isn't used
@export var move_all: bool = false

## where the stacks come from and where they go, never the same unit
@export var from: SkillContext.Who = SkillContext.Who.TARGET
@export var to: SkillContext.Who = SkillContext.Who.USER


## moves the stacks between the real units
## when the target is the user, source and destination are the same unit, so nothing moves and nothing is logged
func apply(context: SkillContext) -> void:
	var source := context.unit(from)
	var destination := context.unit(to)
	if source == destination:
		return
	var how_many := EffectTracker.ALL if move_all else maxi(0, roundi(Formula.evaluate(most, context)))
	var moved := source.effects.transfer(stack_type, how_many, destination.effects)
	context.add_line("%d %s moves from %s to %s" % [
		moved, EffectTracker.label_of(stack_type), context.name_of(source), context.name_of(destination)])


## like "move 1 bleed from the target to yourself"
func describe() -> String:
	var how_many := "every" if move_all else most
	return "move %s %s from %s to %s" % [
		how_many, EffectTracker.label_of(stack_type), SkillContext.who_text(from), SkillContext.who_text(to)]


## a transfer always has the target on one side
func uses_target() -> bool:
	return true
