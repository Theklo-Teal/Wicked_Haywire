@tool
extends Electronics

static func toybox_included() -> bool:
	return false

@export var duty_high : int = 20
@export var duty_low : int = 40
@export var phase : int = 0

var sock : BitOutput

func _ready() -> void:
	#TODO add `sockets`.
	#TODO add `description`
	#TODO set `options`
	#TODO set `dwell` and `delay`
	
	sock = sockets.keys()[0]

func _update_layout():
	match facing:
		pass

func _sim_update(graph:FlowchartNetwork):
	var ticks = graph.sim_ticks + phase
	if posmod(ticks, duty_high) == 0:
		sock.write(0, "int", bitwidth)
	if posmod(ticks, duty_low) == 0:
		sock.write(1, "int", bitwidth)


func _on_low_value_changed(value: float) -> void:
	duty_low = floori(value)
func _on_high_value_changed(value: float) -> void:
	duty_high = floori(value)
