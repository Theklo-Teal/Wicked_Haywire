@tool
extends Electronics

var last_level : bool
var bit_select : int

func _update(graph:FlowchartGraph):
	if graph.read(%Step).val > 0 != last_level:
		last_level = not last_level
		if last_level == true:
			var val : int = graph.read(%input).val
			bit_select = bit_select + 1 % %input.bitwidth
			graph.write(%sequence, {
				"val": [graph.read(%Lower), graph.read(%Upper)][val >> bit_select & 1]
				})
