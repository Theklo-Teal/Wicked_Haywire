extends NetBase.Joint
class_name FlowchartVia

## A simple Joint that isn't associated with Gizmos and to be used
## as the ending of a wire, to tap bits from a wire and, can be labelled to
## create a tunnel connection.

@export var text : String = ""

func draw(chart:Flowchart, canvas:Control, where:Vector2):
	var color = chart.trace_color_secondary
	if chart.sel_vert == self or self in chart._selected:
		color = chart.trace_color_primary
	canvas.draw_circle(where, chart._joint_rad * 0.5 * chart.zoom, color, false, chart._joint_rad * 0.3)
