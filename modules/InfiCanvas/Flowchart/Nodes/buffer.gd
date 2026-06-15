@tool
extends Electronics

## This device is fundamentally a tri-state buffer, but it can act like a diode and the NOT gate, depending on which inputs are negated or set high.

var common_hiz := true
var draw_not_bubble := false

func _update(graph:FlowchartGraph):
	var hiz = graph.read(%enable).val
	if common_hiz:
		hiz = [0, 1 << %output.bitwidth - 1][int(hiz > 0)]
	var val = graph.read(%input).val
	graph.write(%output, {"val":val, "hiz":hiz})
	
	draw_not_bubble = %input.show_check

func _draw() -> void:
	if draw_not_bubble:
		draw_circle(get_socket_position(%output), _get_grid_size() * 0.7, Color.BLACK, false, 3)
