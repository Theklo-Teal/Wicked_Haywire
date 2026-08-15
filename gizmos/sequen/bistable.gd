@tool
extends Electronics

var zet : BitInput
var rst : BitInput
var pos : BitOutput
var neg : BitOutput
var state : bool

static func toybox_included() -> bool:
	return true

func _ready() -> void:
	state = G.rng.randf() >= 0.5
	zet = sockets.keys()[0]
	rst = sockets.keys()[1]
	pos = sockets.keys()[2]
	neg = sockets.keys()[3]
	
	await get_tree().process_frame
	pos.write_bool(0, state)
	neg.write_bool(0, not state)

func _sim_update_sampling(_graph:FlowchartNetwork):
	match int(zet.read_bool()) | (int(rst.read_bool()) << 1):
		0b01:
			state = true
		0b10:
			state = false
		0b11:
			state = not state

func _sim_update_respond(_graph:FlowchartNetwork):
	pos.write_bool(0, state)
	neg.write_bool(0, not state)
