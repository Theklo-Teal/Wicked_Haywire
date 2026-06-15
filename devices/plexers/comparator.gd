@tool
extends Electronics

## Compares the value of two input, responding whether they are equal, lesser or greater.[br]
## Can be made to behave like a Minecraft Comparator in subtraction mode by using the difference output, rather the regular ones.

func _update(graph:FlowchartGraph):
	var A = graph.read(%A).val
	var B = graph.read(%B).val
	var subtr = (A - B).abs()
	graph.write(%differ, {"val": subtr, "hiz":0})
	graph.write(%great, {"val": int(A > B), "hiz":0})
	graph.write(%equal, {"val": int(A == B), "hiz":0})
	graph.write(%less, {"val": int(A < B), "hiz":0})
