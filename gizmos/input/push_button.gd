@tool
extends Electronics

@export var key_mode : Dictionary[Key, bool] = {KEY_1: false}  ## Keyboard keys that control this switch and whether they behave as toggles, rather than momentary switches.
@export var key_bit : Dictionary[Key, int] = {KEY_1: 0}  ## Which bit the
var sock : BitOutput
var state : bool

static func toybox_included() -> bool:
	return true

func _ready() -> void:
	sock = sockets.keys()[0]

var _state_start : bool
var _drag_start : float
func _hover_input(event: InputEvent) -> void:
	if owner.mode == Flowchart.Mode.SIMULAT:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				queue_redraw()
				if event.is_pressed():
					_drag_start = event.position.x
					_state_start = state
					state = not state
				else:
					state = _state_start
			elif event.button_index == MOUSE_BUTTON_RIGHT and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and event.is_released():
				_state_start = state
		
		if event is InputEventKey:
			var bit = key_bit.get(event.keycode, -1)
			var toggle = key_mode.get(event.keycode, false)
			if bit >= 0:
				if event.is_pressed() and not event.is_echo():
					state = not state if toggle else true
				elif event.is_released():
					if not toggle: state = false
 
func _set_bitwidth():
	sock.bitwidth = bitwidth

func _draw():
	super()
	
	draw_style_box(panelstyle[2 if state else 1], Rect2(
		Vector2((size.x - Flowchart.SNAP * 2) if state else 0.0, Flowchart.SNAP * 0.14),
		Vector2(Flowchart.SNAP, Flowchart.SNAP * 0.8)
		))

func _sim_update(_graph:FlowchartNetwork):
	sock.write_bool(0, state)
