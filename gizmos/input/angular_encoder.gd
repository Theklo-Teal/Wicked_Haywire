@tool
extends Electronics

static func toybox_included() -> bool:
	return true

@export var looping : bool
@export var exponetial : bool
@export var expo_curve : Curve
var sock : BitOutput
var input_fence : Rect2

func _ready() -> void:
	#TODO add `description`
	#TODO set `options`
	#TODO set `dwell` and `delay`
	
	sock = sockets.keys()[0]

func _on_resized():
	super()
	input_fence = Rect2(Vector2.ZERO, size).grow(10)

func _draw() -> void:
	super()
	draw_circle(input_fence.get_center(), 12, Color.RED)

func _update_layout():
	match facing:
		pass

func _sim_update_respond(_graph:FlowchartNetwork):
	sock.write(roundi(remap($Dial.value, 0, 100, 0, maxval)), "int")

var ini_angle : float
var ini_value : float
func _input(event: InputEvent) -> void:
	super(event)
	if owner is Flowchart and owner.mode == Flowchart.Mode.SIMULAT and _mouse_hover:
		var new_val : float
		if event is InputEventMouseButton:
			if event.is_pressed():
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						ini_angle = input_fence.get_center().angle_to_point(event.position)
						ini_value = $Dial.value
					MOUSE_BUTTON_WHEEL_DOWN:
						new_val = $Dial.value + 1
					MOUSE_BUTTON_WHEEL_UP:
						new_val = $Dial.value - 1
		
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var center = input_fence.get_center()
			var delta = center.angle_to_point(event.position) - ini_angle
			new_val = ini_value + remap(delta, -PI, PI, 0, 100)
			if not input_fence.has_point(event.position):
				var dir = center.direction_to(event.position)
				Input.warp_mouse(center + dir)
		
		if looping:
			$Dial.value = wrapf(new_val, 0, 100)
		else:
			$Dial.value = clampf(new_val, 0, 100)
