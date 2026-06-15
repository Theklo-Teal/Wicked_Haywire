@tool
extends FlowchartSocket
class_name FlowchartSocketSink

## A kind of socket meant to only read or receive signals, allowing input to their parent GraphNodes.

func _ready() -> void:
	color = Color.MEDIUM_BLUE
	menu.clear()
	menu.add_check_item("Invert Signal")

func _set_link(l:FlowchartGraph.Link):
	l.bitwidth = max(bitwidth, l.bitwidth)
	link = l
