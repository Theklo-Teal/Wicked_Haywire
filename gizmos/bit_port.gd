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
func sim_cycle_begin(_graph:FlowchartNetwork):
	G.rng.randi()  # Advances the RNG State for this port, so different ports will have different RNG outcomes.
	rng_cycle_state = G.rng.state


func _integrate():
	value.width = 1
	var hizs : PackedInt32Array
	
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

func to_int(data:Electronics.BitData) -> int:
	G.rng.state = rng_cycle_state
	var conflict = data.up & data.down
	var noisy = data.hiz | conflict
	var valid = Electronics.invert_max(noisy, data.maxval)
	data.bits = Electronics.set_low(data.bits, data.down & valid, data.maxval)
	data.bits = Electronics.set_high(data.bits, data.up & valid, data.maxval)
	data.bits = Electronics.set_bits(data.bits, G.rng.randi(), noisy)
	return data.bits
