@tool
extends FlowchartSocket
class_name FlowchartSocketBidir

## A sort of wildcard socket when it needs to read or write depending on context.[br]
## It represents ports which have a "high impendance" or disabled state where they won't be affected or a affect their connections unless these connections are free, rather than busy.[br]
## Often the node logic will have a way to address which of the Bidir sockets can access the Link values.

@export var enabled : bool :  ## Is this socket expected to source a signal?
	set(val):
		enabled = val
		queue_redraw()

func _ready() -> void:
	color = Color.ORANGE_RED
	alt_color = Color.BLUE


func _set_link(l:FlowchartGraph.Link):
	l.bitwidth = max(bitwidth, l.bitwidth)
	link = l


func _draw() -> void:
	var thick = min(size.x, size.y) * 0.2
	var rect = Rect2(Vector2.ZERO, Vector2.ONE * min(size.x, size.y))
	var rect_small = rect.grow(-thick)
	
	var color_1 = [color, alt_color][int(enabled)]
	var color_2 = [alt_color, color][int(enabled)]
	
	if mouse_over:
		draw_rect(rect, color_2, false, thick)
	if button_pressed:
		draw_rect(rect, color_1, true)
	else:
		draw_rect(rect_small, color_1, false, thick)
	if show_name:
		draw_label(name)
