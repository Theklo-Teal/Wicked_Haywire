extends NetBase.Port
class_name BitPort

static func get_protocol_name() -> Variant:
	return &"BitData"
static func get_protocol() -> Variant:
	return Electronics.BitData

static func default_link():
	return &"BitCable"

static func default_value() -> Variant:
	return Electronics.BitData.new(1)

func _init() -> void:
	value = default_value()

# This keeps electronic noise when reading consistent regardless of how many
# times functions that use RNG are called in the same sim cycle.
var rng_cycle_state : int
func _sim_cycle_begin(_graph:FlowchartNetwork):
	G.rng.randi()  # Advances the RNG State for this port, so different ports will have different RNG outcomes.
	rng_cycle_state = G.rng.state

func _integrate() -> int:
	value.width = 1
	var hizs : PackedInt32Array
	value.up = 0
	value.down = 0
	
	for entry : Electronics.BitData in aggregate:
		value.width = max(value.width, entry.width)
		hizs.append(value.maxval ^ entry.hiz)
		
		value.up |= entry.up
		value.down |= entry.down
		value.bits = Electronics.set_bits(value.bits, entry.bits, entry.maxval)
	
	# Resulting Hi-Z is to only be set 0 at any digit if there's just a single entry Hi-Z of 0.
	var hiz : int = 0
	var digit : int = -1
	for count in Electronics.parallel_bit_count(hizs, value.width):
		digit += 1
		hiz |= int(count != 1) << digit
	value.hiz = hiz
	
	return to_int(value)

func to_int(data:Electronics.BitData) -> int:
	var result : int = data.bits
	G.rng.state = rng_cycle_state
	var conflict = data.up & data.down
	var noisy = data.hiz | conflict
	var valid = data.hiz & (data.maxval ^ conflict)
	result = Electronics.set_bits(result, G.rng.randi(), noisy)
	result = Electronics.set_low(result, data.down & valid, data.maxval)
	result = Electronics.set_high(result, data.up & valid, data.maxval)
	return result

## Return only certain bits from the value. Negative arguments wrap around the bitwidth
## of this port's value.
func read_splice(data:Electronics.BitData, from:int, to:int):
	from = posmod(from, data.width + 1)
	to = posmod(to, data.width + 1)
	var start = min(from, to)
	var stop = max(from, to)
	var pack = Electronics.BitData.new(stop - start)
	pack.bits = (data.bits >> start) & pack.maxval
	pack.hiz = (data.hiz >> start) & pack.maxval
	pack.up = (data.up >> start) & pack.maxval
	pack.down = (data.down >> start) & pack.maxval
	return pack
