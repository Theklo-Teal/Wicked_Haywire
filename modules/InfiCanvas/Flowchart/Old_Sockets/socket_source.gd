@tool
extends FlowchartSocket
class_name FlowchartSocketSource

## A kind of socket meant to only emit or write signals, allowing their parent GraphNodes to respond.

func _ready() -> void:
	color = Color.ORANGE_RED
	menu.clear()
	menu.add_check_item("Show Signal")

func _set_link(l:FlowchartGraph.Link):
	l.bitwidth = max(bitwidth, l.bitwidth)
	link = l

func has_written(val):
	queue_redraw()
	checked = val > 0
