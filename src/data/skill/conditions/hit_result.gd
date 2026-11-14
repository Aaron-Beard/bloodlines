class_name HitResult
extends SkillCondition
## passes if this target's hit roll went one of the ticked ways
## skills that never roll count as a clean hit
## a shield block is neither a hit nor a miss, so block has its own box

@export var clean: bool = true
@export var graze: bool = true
@export var miss: bool = false
@export var block: bool = false


## checks the target's hit result against the ticked boxes
func passes(context: SkillContext) -> bool:
	if context.blocked:
		return block
	match context.hit_type:
		Enums.HitType.CLEAN:
			return clean
		Enums.HitType.GRAZE:
			return graze
		_:
			return miss


## like "clean or graze"
func describe() -> String:
	var ticked: Array[String] = []
	for pair in [[clean, "clean"], [graze, "graze"], [miss, "miss"], [block, "block"]]:
		if pair[0]:
			ticked.append(pair[1])
	return " or ".join(ticked)

## always about the target
func is_about_target() -> bool:
	return true
