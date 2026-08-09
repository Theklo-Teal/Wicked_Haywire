@tool
extends Electronics

static func toybox_included() -> bool:
	return true

@export var state : bool

var gate : BitInput
var throw : BitRelay
var pole1 : BitRelay
var pole2 : BitRelay

func _ready() -> void:
	#TODO add `sockets`.
	#TODO add `description`
	#TODO set `options`
	#TODO set `dwell` and `delay`
	
	gate = sockets.keys()[0]
	throw = sockets.keys()[1]
	pole1 = sockets.keys()[2]
	pole2 = sockets.keys()[3]

func _update_layout():
	match facing:
		pass

func _sim_update(_graph:FlowchartNetwork):
	state = gate.read("bool")

func _sim_update_respond(_graph:FlowchartNetwork):
	var pole = [pole1, pole2][int(state)]
	var pole_val = pole.read()
	throw.write(pole_val)
	pole.write(throw.read())
