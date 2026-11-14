class_name CombatRng
extends RefCounted
## this is where all the functions that handle rng come from
## every random roll in combat goes through here, never the global randf() or randi()
## same seed means the exact same fight, which is what makes fights replayable

var _rng := RandomNumberGenerator.new()


## sets the seed, so the same seed always rolls the same numbers in the same order
func _init(seed_value: int) -> void:
	_rng.seed = seed_value


## true with the given chance, so chance(0.25) is true about a quarter of the time
## 0 or below always fails and 1.0 or above always succeeds, without rolling at all
## randf() can land on exactly 0.0 or 1.0, so these two checks keep the edges from going the wrong way
func chance(probability: float) -> bool:
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return _rng.randf() <= probability


## a random item from the list, every item equally likely
## the list can't be empty
func pick(items: Array) -> Variant:
	assert(not items.is_empty(), "can't pick from an empty list")
	return items[_rng.randi_range(0, items.size() - 1)]
