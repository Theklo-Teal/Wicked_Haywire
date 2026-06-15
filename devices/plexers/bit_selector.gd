@tool
extends Electronics

func _update(graph:FlowchartGraph):
	var select = graph.read(%digit).val
	graph.write(%select, graph.read(%input).val >> select & 1)
