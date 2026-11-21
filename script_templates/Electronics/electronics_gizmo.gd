@tool
extends Electronics

static func toybox_included() -> bool:
	return true

func _ready() -> void:
	#TODO add `sockets`.
	#TODO add `description`
	#TODO set `options`
	#TODO set `dwell` and `delay`
	
	
	#var input_socket = sockets.keys()[0]
	pass

func _set_bitwidth():
	pass

func _update_layout():
	match facing:
		pass

func _entered_sim(_network:FlowchartNetwork):
	pass

## This is always called when the network updates state.
func _sim_update(_network:FlowchartNetwork):
	pass

## This is called at the networks update state, but only if something about a
## owned socket has changed.
func _edge_triggered(_socket: BitInput, _rising:int, _falling:int):
	pass
