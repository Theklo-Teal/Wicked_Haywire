@tool
extends FlowchartGizmo
class_name Electronics

@export_storage var bitwidth : int = 1 : 
	set(val):
		bitwidth = max(1, val)

@export_multiline() var description : String = ""

@export var options : Dictionary[String, StringName]  ## [option_name] -> property_name; Properties of interest for menus.


## Should this show in the Gizmo tray of the Ribbon Menu?
static func toybox_included() -> bool:
	return false

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
