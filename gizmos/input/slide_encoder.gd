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
	#watch_sockets.call_deferred(input_socket)
	pass

var outsock : BitOutput

func _entered_sim(_network:FlowchartNetwork):
	bitwidth = 8
	outsock = sockets.keys()[0]

func _set_bitwidth():
	%VSlider.max_value = (1 << bitwidth) - 1

func _update_layout():
	match facing:
		pass

func _sim_update(_network:FlowchartNetwork):
	outsock.write_int(%VSlider.value)

func _edge_triggered(_socket: BitInput, _rising:int, _falling:int):
	pass

func _sim_update_sampling():
	pass

func _edge_triggered_sampling(_socket: BitInput, _rising:int, _falling:int):
	pass

func _sim_update_respond():
	pass
