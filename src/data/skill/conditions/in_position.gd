class_name InPosition
extends SkillCondition
## passes if the unit is in one of the ticked positions, 0 is the front

## the unit this looks at
@export var who: SkillContext.Who = SkillContext.Who.TARGET

## which positions pass, tick at least one
@export_flags("Position 0", "Position 1", "Position 2", "Position 3") var positions: int = 0


## checks the position on the frozen copy
func passes(context: SkillContext) -> bool:
	var snapshot := context.snapshot(who)
	if snapshot == null:
		return false
	return positions & (1 << snapshot.position) != 0


## like "the target is in position 0 or 1"
func describe() -> String:
	var ticked: Array[String] = []
	for slot in 4:
		if positions & (1 << slot) != 0:
			ticked.append(str(slot))
	return "%s is in position %s" % [SkillContext.who_text(who), " or ".join(ticked)]

## true when it looks at the target
func is_about_target() -> bool:
	return who == SkillContext.Who.TARGET
