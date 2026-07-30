@tool
extends NetBase.Socket
class_name FlowchartSocket

var pressed : bool
var hover : bool
var bitwidth : int

@export var show_check : bool
var checked : bool

#func draw_wires(canvas:Control):
	#for conn in connected:
		#if connected[conn] == null: continue
		#var wire = connected[conn]
		#wire.draw(canvas, G.chart.to_screen_coord(position), G.chart.to_screen_coord(conn.position))

func draw(canvas:Control):
	var color = G.appearance.trace_primary if hover else G.appearance.trace_secondary
	match mode:
		HIZ:
			color = G.appearance.color.inverted()
			canvas.draw_circle(position, G.joint_rad, color)
		SINK:
			var wid = G.joint_rad * 1.4142  # (Square-root of 2)
			canvas.draw_rect(Rect2(-Vector2(0.5, 0.5) * wid + position, Vector2.ONE * wid), color)
		SOURCE:
			var polyline := [
				position + Vector2(0, -G.joint_rad),
				position + Vector2(G.joint_rad, 0),
				position + Vector2(0, G.joint_rad),
				position + Vector2(-G.joint_rad, 0),
			]
			canvas.draw_colored_polygon(polyline, color)
		BIDIR:
			canvas.draw_circle(position, G.joint_rad, color)
	
	#if show_check and checked:
		#canvas.draw_circle(where, G.grid_size * 0.3, color)
	#if pressed:
		#canvas.draw_circle(where, G.grid_size * 0.3 , color, false, 3)
	#elif hover:
		#canvas.draw_circle(where, G.grid_size * 0.5, color, false, 3)
	#else:
		#canvas.draw_circle(where, G.grid_size * 0.33 , color, false, 3)

## Opportunity to configure the link
@warning_ignore_start("unused_parameter")
func connecter(other_socket:FlowchartSocket, wire:NetBase.Link):
	pass
#NOTE The connect/disconnect functions are meant to be overriden if desired, in which case knowing the wire might be of interest, altough it isn't relevant by default.
func connectee(other_socket:FlowchartSocket, wire:NetBase.Link):
	pass
#NOTE In principle it only makes sense to have a single disconnect function, but if overriding this function is desired, knowing which socket is asking for disconnect might be of interest.
func disconnecter(other_socket:FlowchartSocket):
	pass
func disconnectee(other_socket:FlowchartSocket):
	pass
@warning_ignore_restore("unused_parameter")
