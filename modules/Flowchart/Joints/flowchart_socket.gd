@tool
extends NetBase.Socket
class_name GizmoSocket

## The type of joint meant to be part of Gizmos. It works a bit like Button node.

var toggle : bool  ## Once pressed it stays pressed until clicked again.
var pressed : bool  ## Is in a pressed state.
var hover : bool  ## Mouse is over.

@export var show_state : bool :  ## The [code]pressed[/code] state affects visual appearance.
	set(val):
		show_state = val
		emit_changed()

func draw(chart:Flowchart, canvas:Control, where:Vector2):
	var color = G.appearance.trace_primary if hover else G.appearance.trace_secondary
	var hover_offset = Flowchart.VIA_HOLE if hover else 0
	var thick = Flowchart.JOINT_RAD - Flowchart.VIA_HOLE + hover_offset
	var radius = Flowchart.JOINT_RAD + hover_offset - thick / 2.0
	var sqr_wid = radius * 1.4142  # (Square-root of 2)
	
	if chart is Flowchart:
		radius *= chart.zoom
	match mode:
		HIZ:
			canvas.draw_rect(Rect2(-Vector2(0.5, 0.5) * sqr_wid + where, Vector2.ONE * sqr_wid), color, false, thick / 2.0)
			canvas.draw_circle(where, radius, color, toggle and pressed and show_state, thick / 2.0)
		SINK:
			var polyline := [
				where + Vector2(0, -radius),
				where + Vector2(radius, 0),
				where + Vector2(0, radius),
				where + Vector2(-radius, 0),
			]
			if toggle and pressed and show_state:
				canvas.draw_colored_polygon(polyline, color)
			else:
				#polyline = Geometry2D.offset_polyline(polyline, radius,Geometry2D.JOIN_SQUARE)
				canvas.draw_polyline(polyline + [polyline[0]], color, thick)
		SOURCE:
			canvas.draw_rect(Rect2(-Vector2(0.5, 0.5) * sqr_wid + where, Vector2.ONE * sqr_wid), color, toggle and pressed and show_state, thick)
		BIDIR:
			canvas.draw_circle(where, radius, color, toggle and pressed and show_state, thick)
