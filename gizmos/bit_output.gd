@tool
extends GizmoSocket
class_name BitOutput

func _init() -> void:
	super()
	mode = SOURCE
	toggle = true
	port_class = &"BitPort"
	accepted_port = [&"BitPort"]

func mouse_press():
	show_state = not show_state

func _has_written(val:Electronics.BitSignal):
	pressed = val.bits > 0

func draw(chart:Flowchart, canvas:Control, where:Vector2):
	var color = Color.DARK_GRAY
	var hover_offset = Flowchart.VIA_HOLE if hover else 0
	var thick = Flowchart.JOINT_RAD - Flowchart.VIA_HOLE + hover_offset
	var radius = Flowchart.JOINT_RAD + hover_offset - thick / 2.0
	var sqr_wid = radius * 1.4142  # (Square-root of 2)
	
	if chart is Flowchart:
		radius *= chart.zoom
		color = chart.trace_color_primary if hover else chart.trace_color_secondary
	
	canvas.draw_rect(Rect2(-Vector2(0.5, 0.5) * sqr_wid + where, Vector2.ONE * sqr_wid), color, pressed and show_state, thick)
