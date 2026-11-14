class_name SkillText
extends RefCounted
## a skill in words, for the tooltips on team setup's skill toggles and the fight's skill buttons
## only what's always true of the skill, the fight adds the odds against whoever is in reach on top


## its name and kind, its numbers, who it reaches, and each of its parts, one line each
static func describe(skill: Skill) -> Array[String]:
	var lines: Array[String] = []
	var kind_word: String = Enums.SkillKind.keys()[skill.kind].to_lower()
	lines.append("%s, %s" % [skill.display_name, kind_word])

	# accuracy only means something for skills that roll to hit
	var numbers: Array[String] = []
	if skill.kind != Enums.SkillKind.STATUS:
		numbers.append("power %.0f" % skill.base_power)
	if skill.rolls_hit_chance():
		numbers.append("accuracy %d%%" % roundi(skill.base_hit_chance * 100.0))
	numbers.append("cooldown x%.2f" % skill.cooldown_mult)
	lines.append("   ".join(numbers))

	var verb := "heals" if skill.kind == Enums.SkillKind.HEAL else "hits"
	if skill.kind == Enums.SkillKind.STATUS:
		verb = "affects"
	var how_many := "one" if skill.targeting == Enums.Targeting.CHOSEN else "every"
	var side: String = ["enemy", "ally", "other ally", ""][skill.reaches]
	var slots := ", ".join(skill.valid_target_positions.map(func(slot): return str(slot)))
	var position_word := "position" if skill.valid_target_positions.size() == 1 else "positions"
	if skill.reaches == Enums.Reaches.SELF:
		lines.append("%s yourself" % verb)
	else:
		lines.append("%s %s %s in %s %s" % [verb, how_many, side, position_word, slots])

	if skill.unmissable:
		lines.append("can't miss")
	for part in skill.parts:
		lines.append(part_text(part))
	return lines


## one part in words, like "on hit: poison x1 for 3 turns on the target, if crit"
## a condition about the target in on use or on resolution also says if it's for each, any or every target
static func part_text(part: SkillPart) -> String:
	var text := "%s: %s" % [SkillPart.window_name(part.window), part.describe()]
	var condition := part.condition
	if condition != null:
		text += ", if %s" % condition.describe()
		var once_per_use := part.window == SkillPart.SkillWindow.ON_USE or part.window == SkillPart.SkillWindow.ON_RESOLUTION
		if once_per_use and condition.is_about_target():
			text += " (%s target)" % ["each", "any", "every"][condition.target_rule]
	return text
