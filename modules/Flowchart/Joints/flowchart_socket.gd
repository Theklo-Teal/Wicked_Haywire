@tool
extends NetBase.Socket
class_name GizmoSocket

## The type of joint meant to be part of Gizmos. It works a bit like Button node.[br]

var toggle : bool  ## Once pressed it stays pressed until clicked again.
var pressed : bool  ## Is in a pressed state.
var hover : bool  ## Mouse is over.

@export var show_state : bool = true :  ## The [code]pressed[/code] state affects visual appearance.
	set(val):
		show_state = val
		emit_changed()

func mouse_press():
	if toggle:
		pressed = not pressed
	else:
		pressed = true

func mouse_release():
	if not toggle: pressed = false

func draw(chart:Flowchart, canvas:Control, where:Vector2):
	if chart == null:
		return super(chart, canvas, where)
		
	var color = Color.DARK_GRAY
	@warning_ignore("incompatible_ternary")
	var hover_offset = chart._via_hole if hover else 0
	var thick = chart._joint_rad - chart._via_hole + hover_offset
	var radius = chart._joint_rad + hover_offset - thick / 2.0
	var sqr_wid = radius * 1.4142  # (Square-root of 2)
	
	radius *= chart.zoom
	color = chart.trace_color_primary if hover else chart.trace_color_secondary
	
	match mode:
		HIZ:
			canvas.draw_rect(Rect2(-Vector2(0.5, 0.5) * sqr_wid + where, Vector2.ONE * sqr_wid), color, false, thick / 2.0)
			canvas.draw_circle(where, radius, color, pressed and show_state, thick / 2.0)
		SINK:
			var polyline := [
				where + Vector2(0, -radius),
				where + Vector2(radius, 0),
				where + Vector2(0, radius),
				where + Vector2(-radius, 0),
			]
			if pressed and show_state:
				canvas.draw_colored_polygon(polyline, color)
			else:
				#polyline = Geometry2D.offset_polyline(polyline, radius,Geometry2D.JOIN_SQUARE)
				canvas.draw_polyline(polyline + [polyline[0]], color, thick)
		SOURCE:
			canvas.draw_rect(Rect2(-Vector2(0.5, 0.5) * sqr_wid + where, Vector2.ONE * sqr_wid), color, pressed and show_state, thick)
		BIDIR:
			canvas.draw_circle(where, radius, color, pressed and show_state, thick)
