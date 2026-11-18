@tool
extends Electronics

#TODO Make multi-bit (DIP switch on a bus)

@export var key_mode : Dictionary[Key, bool] = {KEY_1: true}  ## Keyboard keys that control this switch and whether they behave as toggles, rather than momentary switches.
@export var key_bit : Dictionary[Key, int] = {KEY_1: 0}  ## Which bit a Keyboard key affects.
var sock : BitOutput
var state : bool
var throw : bool

static func toybox_included() -> bool:
	return true

func _ready() -> void:
	sock = sockets.keys()[0]
func _entered_sim():
	_sim_update()

func _hover_input(event: InputEvent) -> void:
	if owner.mode == Flowchart.Mode.SIMULAT:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				queue_redraw()
				if event.is_pressed():
					state = not throw
				else:
					state = throw
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if event.is_pressed():
					queue_redraw()
					throw = not state
					state = not state

func _set_bitwidth():
	sock.bitwidth = bitwidth

func _draw():
	super()
	
	draw_style_box(panelstyle[2 if state else 1], Rect2(
		Vector2((size.x - _snap * 2) if state else 0.0, _snap * 0.14),
		Vector2(_snap, _snap * 0.8)
		))

func _sim_update() -> Array[NetBase.Port]:
	if owner.mode == Flowchart.Mode.SIMULAT:
		for klavo in key_bit:
			var kenlet = key_bit[klavo]
			var ken_state = Input.is_key_pressed(klavo) != state
			sock.write_bool(kenlet, ken_state)
	else:
		sock.write_bool(0, state)
	return []
