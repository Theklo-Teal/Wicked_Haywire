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

func _set_bitwidth():
	pass

func _update_layout():
	match facing:
		pass

func _sim_update():
	pass

func _edge_triggered(_socket: BitInput, _rising:int, _falling:int):
	pass

func _sim_update_sampling():
	pass

func _edge_triggered_sampling(_socket: BitInput, _rising:int, _falling:int):
	pass

func _sim_update_respond():
	pass
