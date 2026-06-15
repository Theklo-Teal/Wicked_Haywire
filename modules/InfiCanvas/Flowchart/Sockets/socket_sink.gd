@tool
extends ChartSocket
class_name ChartSocketSink

func draw(node:FlowchartNode, where:Vector2):
	var color = Color.DARK_SLATE_BLUE
	var rect := Rect2(
		where - Vector2.ONE * G.grid_size / 2,
		Vector2.ONE * G.grid_size
		)
	if pressed:
		node.draw_rect(rect.grow(-6), color)
	elif hover:
		node.draw_rect(rect, color)
	else:
		node.draw_rect(rect.grow(-3), color)
