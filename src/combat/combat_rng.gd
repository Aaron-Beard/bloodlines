class_name CombatRng
extends RefCounted
## this is where all the functions that handle rng come from
## every random roll in combat goes through here, never the global randf() or randi()
## same seed means the exact same fight, which is what makes fights replayable

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_rng.seed = seed_value


## true with the given chance, so chance(0.25) is true about a quarter of the time
## randf() can land on exactly 1.0, so anything at 1.0 or above is checked first to always be true
func chance(probability: float) -> bool:
	if probability >= 1.0:
		return true
	return _rng.randf() < probability


## a random index from 0 to count - 1
func pick_index(count: int) -> int:
	return _rng.randi_range(0, count - 1)
