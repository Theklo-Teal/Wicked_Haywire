extends NetBase.Link
class_name BitCable

func draw(chart:Flowchart, canvas:Control, start:Vector2, stop:Vector2):
	var verts = get_verts(start, stop)
	canvas.draw_polyline(verts, Color.WHITE, wire_thick(chart))
	canvas.draw_polyline(verts, chart.trace_color_secondary, wire_thick(chart) - 4)
