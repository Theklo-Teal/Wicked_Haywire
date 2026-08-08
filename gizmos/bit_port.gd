extends NetBase.Port
class_name BitPort

static func get_protocol_name() -> Variant:
	return &"BitSignal"
static func get_protocol() -> Variant:
	return Electronics.BitSignal

static func default_link():
	return &"BitCable"

static func default_value() -> Variant:
	return Electronics.BitSignal.new(1)

func _init() -> void:
	value = default_value()

# This keeps electronic noise when reading consistent regardless of how many
# times functions that use RNG are called in the same sim cycle.
var rng_cycle_state : int
func sim_cycle_begin(_graph:FlowchartNetwork):
	G.rng.randi()  # Advances the RNG State for this port, so different ports will have different RNG outcomes.
	rng_cycle_state = G.rng.state

func _integrate():
	if aggregate.size() == 0: return
	value.width = 1
	var hizs : PackedInt32Array
	
	for entry : Electronics.BitSignal in aggregate:
		value.width = max(value.width, entry.width)
		hizs.append(value.maxval ^ entry.hiz)
		
		value.up |= entry.up
		value.down |= entry.down
		value.bits = entry.bits
	
	# Resulting Hi-Z is to only be set 0 at any digit if there's just a single entry Hi-Z 0.
	var hiz : int = 0
	var digit : int = -1
	for count in Electronics.parallel_bit_count(hizs, value.width):
		digit += 1
		hiz |= int(count == 1) << digit
	value.hiz = hiz

func to_int(data:Electronics.BitSignal) -> int:
	G.rng.state = rng_cycle_state
	#var conflict = up & down
	#var agreed = maxval & conflict & hiz
	#var noisy = hiz | conflict
	#var noised = G.rng.randi() & noisy + 1
	#var deter = maxval ^ noisy
	#var valid = bits & deter
	#valid |= up & agreed
	#valid |= down & agreed
	#var value = valid & noised
	#return value
	var noise = G.rng.randi() & data.hiz
	var valid = data.bits & (data.maxval ^ data.hiz)
	return noise | valid

## Return the boolean state of the bit at the given digit. 0 is the least significant.
func read_bool(data:Electronics.BitSignal, bitwidth:int=1, digit:=0) -> bool:
	data.width = bitwidth
	return to_int(data) & (1 << digit) == 1

## Return an array of bools for all bits.
func read_array(data:Electronics.BitSignal, bitwidth:int=1) -> Array[bool]:
	data.width = bitwidth
	var result : Array[bool]
	var val = to_int(data)
	for d in range(data.width):
		result.append( (val >> d) & 1 == 1 )
	return result

## Return all the bits after accounting Hi-Z and pull states.
func read_int(data:Electronics.BitSignal, bitwidth:int=1) -> int:
	data.width = bitwidth
	return to_int(data)

## Write a value where all bits are valid, with a given bitwidth. If some bits
## aren't to be set, include a Hi-Z integer.
func write_value(val:int, bitwidth:int=1, hiz:int=0) -> Electronics.BitSignal:
	var data = Electronics.BitSignal.new(bitwidth)
	data.bits = val
	data.hiz = hiz
	return data

## Write which bits are pulled high, setting a default state if there are no other connections.
func write_pull_up(mask:int, bitwidth:int=1) -> Electronics.BitSignal:
	var data = Electronics.BitSignal.new(bitwidth)
	data.up = mask
	return data

## Write which bits are pulled low, setting a default state if there are no other connections.
func write_pull_down(mask:int, bitwidth:int=1) -> Electronics.BitSignal:
	var data = Electronics.BitSignal.new(bitwidth)
	data.width = bitwidth
	data.down = mask
	return data
