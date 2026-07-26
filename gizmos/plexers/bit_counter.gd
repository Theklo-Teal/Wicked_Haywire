@tool
extends Electronics

func _update(graph:FlowchartGraph):
	var val = count_bits(graph.read(%input).val, true)
	graph.write(%count, {"val": val, "hiz":0})
