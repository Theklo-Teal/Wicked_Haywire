@tool
extends FlowchartGizmo
class_name Electronics

@export var bitwidth : int = 1 : 
	set(val):
		bitwidth = max(1, val)
		maxval = (1 << bitwidth) - 1
		_set_bitwidth()

var maxval : int = 1  ## The value of having all bits set high. This is set when also setting [code]bitwidth[/code], so don't change it otherwise.

## Override this function if something changes when the bitwidth changes
func _set_bitwidth():
	pass

@export var dwell : int :  ## How many simulation ticks it takes to sample inputs or emit outputs.
	set(val):
		dwell = max(0, val)
@export var delay : int :  ## How many simulation ticks for the output to respond to the input, after sampling with [code]dwell[/code].
	set(val):
		delay = max(0, val)

var _edgy_sockets : Dictionary[BitInput, int]  ## A list of sockets being observed for the contigence of their ports changing value.

@export_multiline() var description : String = ""

@export var options : Dictionary[String, StringName]  ## [option_name] -> property_name; Properties of interest for menus.

## Should this show in the Gizmo tray of the Ribbon Menu?
static func toybox_included() -> bool:
	return false

## Registers sockets to be observed in the contigence of changing values.
## Use [code]_edge_triggered()[/code] and [code]_edge_triggered_sampling()[/code]
## to respond to these changed values.[br]
## Can only watch BitInput sockets.
func watch_sockets(...bit_input_socks):
	for sock in bit_input_socks:
		if sock is BitInput:
			_edgy_sockets[sock] = sock.read("int")

func sim_update(graph:FlowchartNetwork):
	var changed : Dictionary[BitInput, Vector2i]
	for sock in _edgy_sockets:
		var curr_val = sock.read("int")
		var diff = curr_val ^ _edgy_sockets[sock]
		if diff > 0:
			var highs = diff & curr_val
			var lows = diff ^ highs
			_edgy_sockets[sock] =  curr_val
			_edge_triggered(graph, sock, highs, lows)
			changed[sock] = Vector2i(highs, lows)
	
	if dwell == 0 or posmod(graph.sim_ticks, dwell) == 0:
		_sim_update_sampling(graph)
		for sock in changed:
			_edge_triggered_sampling(graph, sock, changed[sock].x, changed[sock].y)
	
	if delay == 0 or posmod(graph.sim_ticks, delay) == 0:
		_sim_update_respond(graph)
	
	super(graph)

@warning_ignore_start("unused_parameter")
## Instantaneous response to a simulation update tick. Use [code]_sim_update_sampling[/code]
## to account [code]dwell[/code] and [code]_sim_update_response[/code] to account [code]delay[/code].
func _sim_update(graph:FlowchartNetwork):
	pass
## Called at the time the Gizmo samples inputs due [code]dwell[/code].
func _sim_update_sampling(graph:FlowchartNetwork):
	pass
## Called at the time the Gizmo emits output due [code]delay[/code].
func _sim_update_respond(graph:FlowchartNetwork):
	pass
## Called at sim cycle update, if value on a socket registered with [code]watch_socket[/code]
## has changed, providing which bits were set high or low.
func _edge_triggered(graph:FlowchartNetwork, socket: BitInput, rising:int, falling:int):
	pass
## Similar to [code]_edge_triggered()[/code], but called at the [code]dwell[/code] trigger.
func _edge_triggered_sampling(graph:FlowchartNetwork, socket: BitInput, rising:int, falling:int):
	pass
@warning_ignore_restore("unused_parameter")

class BitSignal extends RefCounted:
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
	
	func _init(bitwidth:int):
		width = bitwidth
	
	func duplicate():
		var dupl = BitSignal.new(width)
		dupl.bits = bits
		dupl.up = bits
		dupl.down = bits
		return dupl


#region Utilities
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
			counts[i] += n >> 1 & 1
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
