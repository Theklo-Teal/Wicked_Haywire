@tool
extends Electronics

@export var button_panel : StyleBox
var sock : BitOutput
var state : bool

static func toybox_included() -> bool:
	return true

func _ready() -> void:
	sock = sockets.keys()[0]

func _gui_input(event: InputEvent) -> void:
	super(event)
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			state = not state
			queue_redraw()

func _draw():
	super()
	
	draw_style_box(button_panel, Rect2(
		Vector2(size.x - Flowchart.SNAP * 2 if state else 0, Flowchart.SNAP * 0.14),
		Vector2(Flowchart.SNAP, Flowchart.SNAP * 0.8)
		))

func _sim_update(_graph:FlowchartNetwork):
	sock.write(int(state), "value")
