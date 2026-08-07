@tool
extends Electronics

var sock : BitInput
var state : bool

static func toybox_included() -> bool:
	return true

func _ready() -> void:
	sock = sockets.keys()[0]
	dwell = 10

func _sim_update_sampling(_graph:FlowchartNetwork):
	var old_state = state
	state = sock.read("bool")
	if state != old_state:
		panels = {Vector4(0,0,-1,-1.5): 1 if state else 0}
		queue_redraw()
