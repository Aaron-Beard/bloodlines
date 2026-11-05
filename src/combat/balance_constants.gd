class_name Balance
extends RefCounted
## this document should contain all constants that will be used in the game for balancing purposes
## basically if any bare number would ever be used in a formula, it's kept here as a named constant

## explaining terminology
## attribute: patience (pat), fervor (fer), intuition (int)
## attribute scaling: a unit's scaling factor for the associated attribute (low, moderate, high)
## combat points: points that contribute to the scaling of offense or defense stats
## percentages are always written as a decimal; 50% is written as 0.50
## if HP percentage is referenced, it refers to MAX HP unless specified otherwise
## most numbers in here are placeholders until playtesting, so don't treat them as final

# STATS
# all six stats (armor, pen, accuracy, dodge, speed, shield regen rate) are calculated the same way
# stat = level * (attribute scaling + fruit bonus + points bonus) * that stat's global mult
# fruit and point bonus are both calculated as bonus = (number of fruits || points) * (bonus per fruit || point)

## what multiplier applies to low/moderate/high scaling for an attribute
## in order in the array from lowest to highest
## [0] is low while [2] is high
const ATTRIBUTE_SCALING: Array[float] = [1.0, 1.5, 2.0]

## attribute scaling added for a given stat added per fruit consumed by a unit
## if constant is 0.025, then 40 fruits adds 1.0 to the scaling for a given stat
## numerator is equivalent to going from low to moderate or moderate to high
## denominator is how many fruits to get that equivalent boost
const ATTRIBUTE_SCALING_PER_FRUIT: = 0.5 / 20.0

## how much scaling one combat point (off/def) is worth
## this contributes additively with fruit bonus and attribute scaling
## numerator is equivalent to going from low to moderate or moderate to high
## denominator is how many points to get that equivalent boost
const COMBAT_POINT_RATIO: = 0.5 / 35.0

# max HP = BASE_HP_PER_LEVEL * level * (1 + COMBAT_POINT_RATIO * defense points)

## max HP per level for a unit with no points invested in defense
## this is basically the base HP all units get by default per level
const BASE_HP_PER_LEVEL: = 25.0

# hit = base_power * level * (1 + COMBAT_POINT_RATIO * offense points)

## damage multiplier when attack results in graze
## this is a multiplier for damage dealt
## therefore 0.75 means 25% of damage was negated, and 75% still goes through
const GRAZE_DAMAGE_MULT: = 0.55

# armor = level * (patience scaling + fruit scaling + defense points scaling)
#         * GLOBAL_ARMOR_MULT

# pen = level * (intuition scaling + fruit scaling + offense points scaling)
#       * GLOBAL_PEN_MULT

# armor_left = armor - pen (never less than 0)

# damage = hit * (hit / (hit + armor left))
# this one looks weird but it's basically taking the normal hit size
# then multiply it by the share of hit + armor that is made up by the hit
# so it's always no greater than 1 (no armor in comparison to hit)
# and always greater than 0 (infinitely more armor than hit size)
# if the armor left is 10 and hit size is 10, then armor makes up half the total, so 50% reduction
# other multipliers like crit and graze occur after this formula is applied

## multiplies every unit's armor, and nothing else
## armor is measured in skill base power: at 5.0, 1.0 patience scaling balances against 5 base power
## raising this number increases the effectiveness of armor in relation to hit size
const GLOBAL_ARMOR_MULT: = 5.0

## multiplies every unit's pen, and nothing else
## at half of GLOBAL_ARMOR_MULT, equal investment in pen vs armor would cause pen to pierce half the armor
## at the same value as GLOBAL_ARMOR_MULT, equal investment would cause pen to ignore armor entirely
## raise this number if armor is not able to be penetrated
## lower this number if pen is ignoring too much armor globally
const GLOBAL_PEN_MULT: = 2.5

# accuracy = level * (PAT bonus + fruit bonus + off bonus) * GLOBAL_ACCURACY_MULT
# dodge = level * (FER bonus + fruit bonus + def bonus) * GLOBAL_DODGE_MULT
# average level = (attacker level + defender level) / 2
# final hit chance = base_hit_chance + (HIT_CHANCE_PER_ACCURACY_DODGE_GAP * (accuracy - dodge) / average level)
# this value is rolled twice 
# two successes is a hit, two misses is a miss, one of each is a grazing hit

## constant factor governing how much hit chance is gained or lost from difference in accuracy and dodge
const HIT_CHANCE_PER_ACCURACY_DODGE_GAP: = 0.12

## multiplies every unit's accuracy, and nothing else
## if this number is high, accuracy values go up globally
## if it is lowered, accuracy values go down globally
const GLOBAL_ACCURACY_MULT: = 1.0

## multiplies every unit's dodge, and nothing else
## if this number is high, dodge values go up globally
## if it is lowered, dodge values go down globally
const GLOBAL_DODGE_MULT: = 1.0

## global lower bound for minimum final hit chance
const FINAL_HIT_CHANCE_MIN: = 0.25

## global upper bound for maximum final hit chance
## left as 100% for now, but can be lowered if we ever want there to always be a miss chance
const FINAL_HIT_CHANCE_MAX: = 1.0

# crit chance = BASE_CRIT_CHANCE
#               + level * (PAT scaling * CRIT_CHANCE_PER_PAT
#                          + offense points * CRIT_CHANCE_PER_OFFENSE_POINT)
# crit damage mult = BASE_CRIT_DAMAGE_MULT
#                    + level * (INT scaling * CRIT_DAMAGE_MULT_PER_INT
#                               + offense points * CRIT_DAMAGE_MULT_PER_OFFENSE_POINT)
# only a clean hit can crit, a graze never does
# no upper limit on crit chance: anything above 1.0 always crits
# no fruit part: there is no crit fruit

## base crit chance all units have regardless of level
const BASE_CRIT_CHANCE: = 0.05

## crit chance gained per level per 1.0 scaling of PAT
const CRIT_CHANCE_PER_PAT: = 0.010

## crit chance gained per level per point of offense
const CRIT_CHANCE_PER_OFFENSE_POINT: = 0.0005

## base damage multiplier for critical hits
const BASE_CRIT_DAMAGE_MULT: = 1.5

## crit damage mult gained per level per 1.0 scaling of INT
const CRIT_DAMAGE_MULT_PER_INT: = 0.020

## crit damage mult gained per level per point of offense
const CRIT_DAMAGE_MULT_PER_OFFENSE_POINT: = 0.0010

# speed = level * (FER scaling + fruit scaling + offense points scaling) * GLOBAL_SPEED_MULT
# cooldown = AV_BASE / speed * the skill's cooldown_mult
# AV (action value) is the fight's clock: the unit with the least AV left acts next

## this number actually doesn't do anything. 
## if it is doubled or halved, the math should all still work the same
## it is just an arbitrarily large constant that other numbers will divide it by
const AV_BASE: = 10000.0

## global multiplier for all units speed
## changing this won't affect unit speed against each other and will always be the same relative speed calculation
## this is only to weight against the global shield regen stat
## if regen is too high relative to speed, nobody will ever take damage
## if speed is too high relative to regen, no shield will ever recharge 
## generally leave this as 1 and just change shield regen if you are worried about shield recharge rates
const GLOBAL_SPEED_MULT: = 1.0

# shield regen speed = level * (INT scaling + fruit scaling + defense points scaling)
#                      * GLOBAL_SHIELD_REGEN_MULT
# AV per shield charge = AV_BASE / shield regen speed

## global multiplier for shield regen rates
## this must be primarily weighed against global speed mult
const GLOBAL_SHIELD_REGEN_MULT: = 0.2

## this is the maximum amount of shield charges a unit can have
## this is based solely on your inherent scaling for INT
## in order of low, moderate, high
const SHIELD_CAPACITY_BY_INT: Array[int] = [1, 2, 3]

## how many shield charges a unit begins each fight with
## this is based solely on your inherent scaling for INT
## in order of low, moderate, high
const SHIELD_CHARGES_AT_START_BY_INT: Array[int] = [0, 1, 2]

# every buff or debuff stack multiplies
# a buff stack multiplies by the ratio, a debuff stack divides by it,
# so one of each cancels out exactly
# buffs and debuffs are counted separately, up to EFFECT_STACK_LIMIT of each

## multiplier for one stack of any given buff/debuff
## applies to buffs and debuffs for basic stats
## armor, pen, speed, etc
const BUFF_STAT_RATIO: = 5.0 / 4.0

## multiplier for damage done and taken buffs/debuffs
## intentionally weaker since those are more universal stats
## can be changed to the same as buff stat ratio if later wished
const BUFF_DAMAGE_RATIO: = 9.0 / 8.0

## this is the maximum amount of stacks of any unique buff/debuff a unit can have at once
const EFFECT_STACK_LIMIT: = 3

## duration in turns that any buff/debuff lasts if not otherwise specified
## counted in the affected unit's own turns, so faster units burn through them quicker
const DEFAULT_EFFECT_DURATION: = 3

## percentage of max hp that damage over time and heal over time affects
## changing this number will globally make dots and hots stronger or weaker
## dot and hot both ignore armor and shield, and they can never crit
## damage taken up or down stacks still apply to the damage taken from dots
const DOT_HOT_HP_PERCENT: = 0.05

# sudden death: a failsafe mechanic to prevent infinite length fights
# baseline turn = AV_BASE / (level * GLOBAL_SPEED_MULT)
# counters start after SUDDEN_DEATH_START_BASELINE_TURNS,
# then one more every SUDDEN_DEATH_BASELINE_TURNS_PER_COUNTER
# sudden death counters can never be cleansed or purged
# these counters globally reduce all defenses to increase lethality of all units
# realistically this should never be relevant unless a player is intentionally stalling a fight for some reason

## baseline turns that pass before sudden death starts to take effect
## this is not the actual turns that occur in a fight
## it's just measured in a certain amount of turns that a hypothetical baseline unit would take
const SUDDEN_DEATH_START_BASELINE_TURNS: = 30.0

## baseline turns between sudden death counters being added after they start
const SUDDEN_DEATH_BASELINE_TURNS_PER_COUNTER: = 2.5

## percentage of all defenses reduced per counter of sudden death applied by default
const SUDDEN_DEATH_DEFENSE_LOSS_PER_COUNTER: = 0.05

## percentage increased damage taken per counter of sudden death applied by default
const SUDDEN_DEATH_DAMAGE_TAKEN_PER_COUNTER: = 0.05

## percentage of healing received reduced per counter of sudden death applied by default
## for now set to 0
## can be changed later if healing needs to be nerfed during sudden death
## unlikely to be necessary
const SUDDEN_DEATH_HEALING_LOSS_PER_COUNTER: = 0.00

# after combat, each unit heals based on its current state:
# if hp > 0: hp += missing hp * POST_COMBAT_MISSING_HP_HEAL_PERCENT
# else:      hp = max hp * POST_COMBAT_MISSING_HP_HEAL_PERCENT * REVIVE_TO_HEAL_RATIO
# a revived unit gets no heal that fight

## percentage of missing HP that living units heal after a fight by default
const POST_COMBAT_MISSING_HP_HEAL_PERCENT: = 0.30

## this is the ratio of the post combat healing that dead units revive at
## for instance if post combat healing is 30% and this stat is set to 50%
## then a dead unit revives at 15% health after a fight
const REVIVE_TO_HEAL_RATIO: = 0.50

# a unit's free skills never count against EQUIPPED_SKILL_LIMIT

## number of skills a unit can have chosen to use in battle at once from its total pool of skills
const EQUIPPED_SKILL_LIMIT: = 4

## number of total skills in the pool to pick from for a unit
## increases as units rank up to higher evolution forms
## in order of baby, intermediate, final
## free skills are not counted, every species of a tier has exactly this many
const SKILL_POOL_SIZE_BY_TIER: Array[int] = [6, 8, 10]

# augment rarity: each augment offered rolls the upgrade chance twice
# no success = common, one = uncommon, two = rare
# upgrade chance = AUGMENT_UPGRADE_BASE_CHANCE + level * AUGMENT_UPGRADE_CHANCE_PER_LEVEL
# boss augments are a separate pool and are never rolled

## base chance for augments offered to upgrade to a tier higher
const AUGMENT_UPGRADE_BASE_CHANCE: = 0.05

## increased chance for augments to upgrade based on level
const AUGMENT_UPGRADE_CHANCE_PER_LEVEL: = 0.03
