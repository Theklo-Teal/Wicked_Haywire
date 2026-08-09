@tool
extends Electronics

static func toybox_included() -> bool:
	return true

var sock_x : BitOutput
var sock_y : BitOutput
var axis : Vector2i

func _ready() -> void:
	#TODO add `sockets`.
	#TODO add `description`
	#TODO set `options`
	#TODO set `dwell` and `delay`
	
	sock_x = sockets.keys()[0]
	sock_y = sockets.keys()[1]

func _update_layout():
	match facing:
		pass

var delta : Vector2
var ini_mouse : Vector2
func _gui_input(event: InputEvent) -> void:
	super(event)
	if owner is Flowchart and owner.mode == Flowchart.Mode.SIMULAT or owner == null:
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var limit = size.y / 2.0
			queue_redraw()
			delta = (event.position - ini_mouse).clampf(-limit, limit)
			axis.x = roundi(remap(delta.x, -limit, limit, 0, bitwidth))
			axis.y = roundi(remap(delta.y, -limit, limit, 0, bitwidth))
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				ini_mouse = event.position
				Input.mouse_mode =Input.MOUSE_MODE_HIDDEN
			else:
				Input.mouse_mode =Input.MOUSE_MODE_VISIBLE
				delta = Vector2.ZERO
				queue_redraw()

func _draw():
	super()
	draw_circle(size * 0.5, size.y * 0.5, Color.BLACK, false, 5)
	draw_circle(delta + size * 0.5, Flowchart.SNAP, Color.RED)

func _sim_update_respond(_graph:FlowchartNetwork):
	sock_x.write(axis.x, "int", bitwidth)
	sock_y.write(axis.y, "int", bitwidth)
