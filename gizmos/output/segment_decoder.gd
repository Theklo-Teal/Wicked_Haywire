@tool
extends Electronics

static func toybox_included() -> bool:
	return true


var inpsock : BitInput
var outsock : BitOutput
var state : BitPort

func _ready() -> void:
	#TODO add `sockets`.
	#TODO add `description`
	#TODO set `options`
	#TODO set `dwell` and `delay`
	
	inpsock = sockets.keys()[0]
	outsock = sockets.keys()[1]

func _set_bitwidth():
	pass

func _update_layout():
	match facing:
		pass

func _entered_sim(_network:FlowchartNetwork):
	bitwidth = 12

## This is always called when the network updates state.
func _sim_update(_network:FlowchartNetwork):
	outsock.write(state)

## This is called at the networks update state, but only if something about a
## owned socket has changed.
func _edge_triggered(_socket: BitInput, _rising:int, _falling:int):
	state = inpsock.read()
	%Label.text = str(state.to_int()).pad_zeros(3)
