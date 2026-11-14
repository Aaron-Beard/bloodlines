class_name SkillCondition
extends Resource
## a yes/no check on a part, the part only happens if it passes
## a condition only reads, it never changes anything
## it reads the frozen copies from when the window opened, so every part in a window gets the same answer

## for a condition about the target, in a window that runs once per use (on use, on resolution)
## EACH: the part happens once for every target that passes, on resolution only
## ANY: the part happens once if at least one target passes
## ALL: the part happens once if every target passes
## windows that run per target already have their one target, so they don't use this
enum TargetRule { EACH, ANY, ALL }

## how two numbers get compared
enum Comparison { LESS, AT_MOST, EQUAL, AT_LEAST, MORE }

## see TargetRule, only used for a condition about the target in on use or on resolution
@export var target_rule: TargetRule = TargetRule.EACH


## true if the condition passes for this context's target, or just for the user if it never looks at a target
func passes(_context: SkillContext) -> bool:
	assert(false, "every condition type has its own passes()")
	return false


## true if the answer depends on which target it is
func is_about_target() -> bool:
	return false


## the condition in a few words, like "crit", for the hover text
func describe() -> String:
	return ""


## compares two numbers, EQUAL allows for tiny decimal differences
static func compare(left: float, how: Comparison, right: float) -> bool:
	match how:
		Comparison.LESS:
			return left < right
		Comparison.AT_MOST:
			return left <= right
		Comparison.EQUAL:
			return is_equal_approx(left, right)
		Comparison.AT_LEAST:
			return left >= right
		_:
			return left > right


## a comparison in words, like "at least"
static func comparison_text(how: Comparison) -> String:
	return Comparison.keys()[how].to_lower().replace("_", " ")
