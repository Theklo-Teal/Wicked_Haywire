@tool
extends NetBase.Socket
class_name GizmoSocket

var pressed : bool
var hover : bool
var bitwidth : int

@export var show_check : bool
var checked : bool

func draw(canvas:Control, where:Vector2):
	var color = G.appearance.trace_primary if hover else G.appearance.trace_secondary
	match mode:
		HIZ:
			color = G.appearance.color.inverted()
			canvas.draw_circle(where, Flowchart.JOINT_RAD, color)
		SINK:
			var wid = Flowchart.JOINT_RAD * 1.4142  # (Square-root of 2)
			canvas.draw_rect(Rect2(-Vector2(0.5, 0.5) * wid + where, Vector2.ONE * wid), color)
		SOURCE:
			var polyline := [
				where + Vector2(0, -Flowchart.JOINT_RAD),
				where + Vector2(Flowchart.JOINT_RAD, 0),
				where + Vector2(0, Flowchart.JOINT_RAD),
				where + Vector2(-Flowchart.JOINT_RAD, 0),
			]
			canvas.draw_colored_polygon(polyline, color)
		BIDIR:
			canvas.draw_circle(where, Flowchart.JOINT_RAD, color)
	
	#if show_check and checked:
		#canvas.draw_circle(where, G.grid_size * 0.3, color)
	#if pressed:
		#canvas.draw_circle(where, G.grid_size * 0.3 , color, false, 3)
	#elif hover:
		#canvas.draw_circle(where, G.grid_size * 0.5, color, false, 3)
	#else:
		#canvas.draw_circle(where, G.grid_size * 0.33 , color, false, 3)
