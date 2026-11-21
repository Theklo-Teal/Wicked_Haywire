@tool
extends FlowchartGizmo
class_name Electronics

@export var bitwidth : int = 1 : 
	set(val):
		bitwidth = clampi(val, 1, 32)
		maxval = (1 << bitwidth) - 1
		_bitwidth_changed = true

var maxval : int = 1  ## The value of having all bits set high. This is set when also setting [code]bitwidth[/code], so don't change it otherwise.

var _bitwidth_changed : bool = true
func _process(delta: float) -> void:
	super(delta)
	if _bitwidth_changed:
		_bitwidth_changed = false
		_set_bitwidth()

## Override this function if something changes when the bitwidth changes.
## Note that when bitwidth is changed, you have to set the bitwidth of sockets
## that get affected by it accordingly.
func _set_bitwidth():
	pass

@export_multiline() var description : String = ""

@export var options : Dictionary[String, StringName]  ## [option_name] -> property_name; Properties of interest for menus.

## Should this show in the Gizmo tray of the Ribbon Menu?
static func toybox_included() -> bool:
	return false

func sim_update(network:FlowchartNetwork):
	var changed_sockets : Dictionary[GizmoSocket, Vector2i]
	
	for sock in sockets:
		if sock.port.changed and sock is BitInput:
			if typeof(sock.port.past_state) != TYPE_INT: continue
			if typeof(sock.port.curr_state) != TYPE_INT: continue
			var diff = sock.port.past_state ^ sock.port.curr_state
			var highs = diff & sock.port.curr_state
			var lows = diff ^ highs
			changed_sockets[sock] = Vector2i(highs, lows)
			edge_triggered(sock, highs, lows)
	return super(network)

@warning_ignore_start("unused_parameter")
func edge_triggered(socket: BitInput, rising:int, falling:int):
	_edge_triggered(socket, rising, falling)
## Called at sim cycle update, if value on a socket's port has changed, then
## providing which bits were set high or low.
func _edge_triggered(socket: BitInput, rising:int, falling:int):
	pass
@warning_ignore_restore("unused_parameter")


class BitData extends RefCounted:
	## The protocol for Ports managing binary digital signals.
	
	var width : int = 1 :  ## Bit amount of values
		set(val):
			width = clampi(val, 1, 32)
			var mask = (1 << width) - 1  # Find maximum value for this bitwidth
			var new_hiz = (maxval ^ mask) | hiz  # set new bits to hiz, if the width increases.
			maxval = mask
			hiz = new_hiz
	
	var maxval : int = 1  ## Used as a mask to limit the amount of bits stored.
	
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
	
	func _init(bitwidth:int=1):
		width = bitwidth
	
	func to_int() -> int:
		var result : int = bits
		var conflict = up & down
		var noisy = hiz | conflict
		var valid = hiz & (maxval ^ conflict)
		result = Electronics.set_bits(result, G.jiffy_noise, noisy)
		result = Electronics.set_low(result, down & valid, maxval)
		result = Electronics.set_high(result, up & valid, maxval)
		return result
	
	## Returns a new BitData with copied contents of this one. Optionally only
	## copy desired bits selected by the [code]mask[/code].[br]
	## If [code]mask[/code] is zero, it copies all the bits.[br]
	## Shift allows offsetting all bits if necessary. It shifts towards least significant.
	## The [code]width[/code] of the duplicate will be that of the mask after the shift.
	func duplicate(mask:int=0, shift:int=0):
		if mask == 0:
			mask = maxval
		
		var dupl = BitData.new(Electronics.msb_bit_mask(mask >> shift))
		dupl.bits = (bits & mask) >> shift
		dupl.hiz = (hiz & mask) >> shift
		dupl.up = (up & mask) >> shift
		dupl.down = (down & mask) >> shift
		return dupl


#region Utilities
## Get the largest binary number given a number of [code]bits[/code].[br]
## Can also be thought as a value with all bits set high.
static func max_val(bit_width:int) -> int:
	return (1 << bit_width) - 1

## Produces a mask similar to [code]max_val()[/code], but assuming the most significant bit tells the bit width.
static func msb_bit_mask(val:int) -> int:
	var wid : int = 0
	while val > 0:
		# Shift right until all bits disappear
		val = val >> 1
		wid += 1
	return max_val(wid)  # The resulting count of bits is the bitwidth.

## Get all bits inverted, using a [code]mask[/code] to tell which bits.
static func invert_max(val:int, mask:int) -> int:
	return val ^ mask

## Get all bits inverted, using the amount of bits to tell which ones.
static func invert_wid(val:int, bit_width:int) -> int:
	return invert_max(val, max_val(bit_width))

## Set all bits high that are high in the mask.
static func set_high(val:int, high_mask:int, wid_mask:int) -> int:
	return val | (high_mask & wid_mask)

## Set all bits low that are high in the mask.
static func set_low(val:int, low_mask:int, wid_mask:int) -> int:
	return val & invert_max(low_mask, wid_mask)

## Set the bits in [code]val[/code] to bits in [code]new[/code] where
## [code]mask[/code] is high.[br]
## https://graphics.stanford.edu/~seander/bithacks.html#MaskedMerge[br]
static func set_bits(val:int, new:int, mask:int) -> int:
	return val ^ ((val ^ new) & mask);

## Produce an integer which is the concatenation of input bits.
static func parallel_to_int(nums:Array[bool]) -> int:
	var serial : int = 0
	var digit : int = -1
	for n : bool in nums:
		digit += 1
		serial |= int(n) << digit
	return serial

## Return an array which counts the bits at the same binary digit of multiple integers.
static func parallel_bit_count(nums:PackedInt32Array, bit_width:int) -> PackedInt32Array:
	var counts : Array[int] = []
	counts.resize(bit_width)
	counts.fill(0)
	for n in nums:
		for i in range(bit_width):
			counts[i] += (n >> i) & 1
	return counts

## Return how many bits are high or low in an integer.
static func count_bits(n:int, high:bool) -> int:
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
