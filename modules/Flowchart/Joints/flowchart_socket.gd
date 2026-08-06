@tool
extends NetBase.Socket
class_name GizmoSocket

## The type of joint meant to be part of Gizmos. It works a bit like Button node.

var pressed : bool
var hover : bool
var bitwidth : int

@export var show_check : bool : 
	set(val):
		show_check = val
		emit_changed()
var checked : bool

func draw(chart:Flowchart, canvas:Control, where:Vector2):
	var color = G.appearance.trace_primary if hover else G.appearance.trace_secondary
	var hover_offset = Flowchart.VIA_HOLE if hover else 0
	var radius = Flowchart.JOINT_RAD
	if chart is Flowchart:
		radius *= chart.zoom
	match mode:
		HIZ:
			var polyline := [
				where + Vector2(0, -radius + hover_offset),
				where + Vector2(radius + hover_offset, 0),
				where + Vector2(0, radius + hover_offset),
				where + Vector2(-radius + hover_offset, 0),
			]
			if checked and show_check:
				polyline = Geometry2D.offset_polyline(polyline, radius - Flowchart.VIA_HOLE,Geometry2D.JOIN_SQUARE)
				canvas.draw_polyline(polyline, color, Flowchart.VIA_HOLE)
			else:
				canvas.draw_colored_polygon(polyline, color)
		SINK:
			var wid = radius * 1.4142 + hover_offset  # (Square-root of 2)
			color = Color.BLUE
			canvas.draw_rect(Rect2(-Vector2(0.5, 0.5) * wid + where, Vector2.ONE * wid), color)
		SOURCE:
			var wid = radius * 1.4142  + hover_offset  # (Square-root of 2)
			color = Color.ORANGE
			if checked and show_check:
				wid -= Flowchart.VIA_HOLE
				canvas.draw_rect(Rect2(-Vector2(0.5, 0.5) * wid + where, Vector2.ONE * wid), color, false, Flowchart.VIA_HOLE)
			else:
				canvas.draw_rect(Rect2(-Vector2(0.5, 0.5) * wid + where, Vector2.ONE * wid), color)
		BIDIR:
			if checked and show_check:
				canvas.draw_circle(where, radius - Flowchart.VIA_HOLE + hover_offset, color, false, Flowchart.VIA_HOLE)
			else:
				canvas.draw_circle(where, radius + hover_offset, color)
