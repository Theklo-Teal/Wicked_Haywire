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
func parallel_to_serial(nums:PackedInt32Array, bit_width:int):
	var serial : Array[int] = []
	serial.resize(bit_width)
	for n : int in nums:
		for i in range(bit_width):
			var bit = n & (1 << bitwidth)
			serial[i] |= bit

func parallel_bit_count(nums:PackedInt32Array, bit_width:int):
	var counts : Array[int] = []
	counts.resize(bit_width)
	for n in nums:
		for i in range(bit_width):
			counts[i] += n >> 1 & 1
	return counts

func count_bits(n, truth):
	var amount = n
	var count : int = 0
	while n != 0:
		count += 1
		n &= n-1
	if truth:
		return count
	else: 
		amount = String.num_uint64(amount, 2).length()
		return amount - count
#endregion
