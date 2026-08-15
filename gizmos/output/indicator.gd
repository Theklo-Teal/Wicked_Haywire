@tool
extends Electronics

var sock : BitInput
var states : Array[bool] = [false] :
	set(val):
		states = val
		if val.size() == 0:
			states.resize(1)
var state_int : int = 0

static func toybox_included() -> bool:
	return true

func _ready() -> void:
	sock = sockets.keys()[0]

func _set_bitwidth():
	sock.bitwidth = bitwidth
	states.resize(bitwidth)
	states.fill(false)
	panels.clear()
	size.x = Flowchart.SNAP * bitwidth

func _sim_update_sampling(_graph:FlowchartNetwork):
	var old_state = state_int
	states.assign(sock.read_array())
	state_int = sock.read_int()
	if state_int != old_state:
		queue_redraw()

func _draw() -> void:
	for i in range(bitwidth):
		panels[Vector4(i,0,i+1,-1.5)] = 1 if states[i] else 0
	super()

func _on_add_pressed() -> void:
	bitwidth += 1
	if bitwidth > 1:
		%Rem.disabled = false
func _on_rem_pressed() -> void:
	bitwidth -= 1
	if bitwidth <= 1:
		%Rem.disabled = true
