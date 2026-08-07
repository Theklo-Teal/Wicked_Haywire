@tool
extends FlowchartGizmo
class_name Electronics

@export var bitwidth : int = 1 : 
	set(val):
		bitwidth = max(1, val)

@export var dwell : int :  ## How many simulation ticks it takes to sample inputs or emit outputs.
	set(val):
		dwell = max(0, val)
@export var delay : int :  ## How many simulation ticks for the output to respond to the input, after sampling due [code]dwell[/code].
	set(val):
		delay = max(0, val)

@export_multiline() var description : String = ""

@export var options : Dictionary[String, StringName]  ## [option_name] -> property_name; Properties of interest for menus.

## Should this show in the Gizmo tray of the Ribbon Menu?
static func toybox_included() -> bool:
	return false

var _sim_period : int = 0
var _sample_period : int = 0
## Instantaneous response to a simulation update tick. Use [code]_sim_update_sampling[/code]
## to account [code]dwell[/code] and [code]_sim_update_response[/code] to account [code]delay[/code].
func _sim_update(graph:FlowchartNetwork):
	_sim_period += 1
	_sample_period += 1
	if _sim_period > dwell:
		_sim_period = 0
		_sim_update_sampling(graph)
	
	if _sample_period > delay:
		_sample_period = 0
		_sim_update_respond(graph)

@warning_ignore("unused_parameter")
## Called at the time the Gizmo samples inputs due [code]dwell[/code].
func _sim_update_sampling(graph:FlowchartNetwork):
	pass
@warning_ignore("unused_parameter")
## Called at the time the Gizmo emits output due [code]delay[/code].
func _sim_update_respond(graph:FlowchartNetwork):
	pass

class BitSignal extends RefCounted:
	## The protocol for Ports managing binary digital signals.
	
	var maxval : int = 1  ## Used as a mask to limit the amount of bits stored.
	var width : int = 1 :  ## Bit amount of values
		set(val):
			width = clampi(val, 1, 32)
			var mask = (1 << width) - 1  # Find maximum value for this bitwidth
			hiz = (maxval ^ mask) | hiz  # set new bits to hiz, if the width increases.
			maxval = mask
	
	var bits : int = 0 : 
		set(val):
			bits = val & maxval
	var hiz : int = 1 :  ## Bits that are electrically disconnected. They are susceptible to electronic noise if read.
		set(val):
			hiz = val & maxval
	var up : int = 0 :  ## Pulled up, for an HIZ bit, it makes it 1 as default.
		set(val):
			up = val & maxval
	var down : int = 0 :  ## Pulled down, for an HIZ bit, it makes it 0 as default.
		set(val):
			down = val & maxval
	 
	func to_int() -> int:
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
		return G.rng.randi() & maxval


#region Utilities
## Produce an integer which is the concatenation of input bits.
func parallel_to_int(nums:Array[bool]) -> int:
	var serial : int = 0
	var digit : int = -1
	for n : bool in nums:
		digit += 1
		serial |= int(n) << digit
	return serial

## Return an array which counts the bits at the same binary digit of multiple integers.
func parallel_bit_count(nums:PackedInt32Array, bit_width:int) -> PackedInt32Array:
	var counts : Array[int] = []
	counts.resize(bit_width)
	counts.fill(0)
	for n in nums:
		for i in range(bit_width):
			counts[i] += n >> 1 & 1
	return counts

## Return how many bits are high or low in an integer.
func count_bits(n:int, high:bool) -> int:
	var amount = n
	var count : int = 0
	while n != 0:
		count += 1
		n &= n-1
	if high:
		return count
	else: 
		amount = String.num_uint64(amount, 2).length()
		return amount - count
#endregion
