@tool
extends Electronics

## Compares input with given value, outputting high if they are equal.
## Use a Comparator for varying address.

var address : int

func _update(graph:FlowchartGraph):
	var truth = graph.read(%input).val == address
	graph.write(%output, {"val": int(truth), "hiz":0})
