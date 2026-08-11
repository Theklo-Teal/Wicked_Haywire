@tool
extends Electronics

static func toybox_included() -> bool:
	return true

@export var exponential : bool
@export var expo_curve : Curve
var value : int
var sock : BitOutput

func _ready() -> void:
	#TODO add `description`
	#TODO set `options`
	#TODO set `dwell` and `delay`
	
	
	sock = sockets.keys()[0]

func _update_layout():
	match facing:
		pass

func _sim_update_respond(_graph:FlowchartNetwork):
	sock.write(value, "int")

func _on_h_slider_value_changed(val: float) -> void:
	if exponential:
		value = roundi(expo_curve.sample_baked(val) * maxval)
	else:
		value = roundi(remap(val, 0, 100, 0, maxval))


var is_resizing : bool
var ini_size : Vector2
func _on_resize_handle_button_down() -> void:
	ini_size = size
	is_resizing = true

func _on_resize_handle_button_up() -> void:
	is_resizing = false

func _input(event: InputEvent) -> void:
	super(event)
	if owner is Flowchart and owner.mode == Flowchart.Mode.EDITING:
		if event is InputEventMouseMotion and is_resizing:
			var delta = event.position - ini_size
			size.x = delta.x
