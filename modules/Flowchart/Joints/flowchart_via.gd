extends NetBase.Joint
class_name FlowchartVia

## A simple Joint that isn't associated with Gizmos and to be used
## as the ending of a wire, to tap bits from a wire and, can be labelled to
## create a tunnel connection.

@export var text : String = ""
@export_storage var tapping : Array[int]  ## This tells which bits from a bus to relay.

func draw(canvas:Control, where:Vector2):
	var color = G.appearance.trace_secondary
	if canvas is Flowchart and canvas.sel_vert == self: color = G.appearance.trace_primary
	canvas.draw_circle(where, Flowchart.JOINT_RAD, color, false, 4)
