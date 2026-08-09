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

func _sim_update_sampling(_graph:FlowchartNetwork):
	match int(zet.read("bool")) | (int(rst.read("bool")) << 1):
		0b01:
			state = true
		0b10:
			state = false
		0b11:
			state = not state

func _sim_update_respond(_graph:FlowchartNetwork):
	pos.write(int(state), "value", bitwidth)
	neg.write(int(not state), "value", bitwidth)
