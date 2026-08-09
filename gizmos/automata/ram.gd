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
	
	mouse_entered.connect(_show_contents)
	mouse_exited.connect(_hide_contents)

func _show_contents():
	$Edit_Panel.show()

func _hide_contents():
	$Edit_Panel.show()

func _update_layout():
	match facing:
		pass

func _sim_update(graph:FlowchartNetwork):
	pass

func _edge_triggered(graph:FlowchartNetwork, socket: BitInput, rising:int, falling:int):
	pass

func _sim_update_sampling(graph:FlowchartNetwork):
	pass

func _edge_triggered_sampling(graph:FlowchartNetwork, socket: BitInput, rising:int, falling:int):
	pass

func _sim_update_respond(graph:FlowchartNetwork):
	pass
