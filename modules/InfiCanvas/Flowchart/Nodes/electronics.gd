@tool
extends FlowchartNode
class_name Electronics

@export_storage var bitwidth : int = 1 : set=set_bitwidth

func set_bitwidth(val:int):
	bitwidth = max(1, val)

enum AXLE{
	HORIZ = 0,
	VERTI = 1
}
enum FACE{
	EAST = 0,
	SOUTH = 010,
	WEST = 100,
	NORTH = 110
}
enum MIRROR{
	NONE = 0,
	HORIZ = 0b01000,
	VERTI = 0b10000,
	BOTH = 0b11000
}
enum ALTER{
	NONE,
	SPREAD = 0b0100000,
	A = 0b1000000,
	B = 0b1100000
}

@export var layout_code : int : 
	set(val):
		layout_code = val & 0b1111111
		layout_axle = layout_code & 0b1 as AXLE
		layout_face = layout_code & 0b110 as FACE
		layout_mirror = layout_code & 0b11000 as MIRROR
		layout_alter = layout_code & 0b1100000 as ALTER
	get():
		return layout_axle | layout_face | layout_mirror | layout_alter as int
		
@export_group("Layout", "layout")
@export var layout_axle : AXLE
@export var layout_face : FACE
@export var layout_mirror : MIRROR
@export var layout_alter : ALTER

@export_multiline() var description : String = ""

var layout_variants : Array[Control]
func get_layout():
	return layout_variants[layout_code]
func set_layout(code:int):
	layout_code = code

func _init() -> void:
	super()
	var scene = choose_scene()
	if scene == null:
		for each in get_children():
			each.queue_free()
	else:
		add_child(scene)
		scene.owner = self

func choose_scene() -> Control:
	return null

var options : Dictionary[String, StringName]  ## [option_name] -> property_name; Properties of interest for menus.



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
