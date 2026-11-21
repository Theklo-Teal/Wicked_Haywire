@tool
extends GizmoSocket
class_name BitInput

enum {
	NONE,
	PULL_DN,
	PULL_UP,
	INVERT
}

@export_enum("None", "Pull Down", "Pull Up", "Invert") var variant : int
@export var bitwidth : int = 1 : 
	set(val):
		bitwidth = clamp(val, 1, 32)

func _init() -> void:
	super()
	mode = SINK
	toggle = true
	port_class = &"BitPort"
	accepted_port = [&"BitPort"]

func mouse_press():
	variant = (variant + 1) % 4
	pressed = variant == INVERT
func mouse_release():
	# Clear default behavior.
	return


## This applies socket options to BitData before extracting information of
## interest from it.
func read_int() -> int:
	var val : Electronics.BitData = port.value.duplicate()
	val.width = bitwidth
	match variant:
		PULL_DN:
			val.down = val.maxval
			val.up = 0
		PULL_UP:
			val.down = 0
			val.up = val.maxval
		INVERT:
			val.bits = val.bits ^ val.maxval
	var result = val.to_int()
	_has_read(result)
	has_read.emit(result)
	return result

## Returns the bool state of the given bit.
func read_bool(digit:int=0) -> bool:
	return ((read_int() >> digit) & 1) > 0

## Returns the bool state of all bits.
func read_array() -> Array[bool]:
	var arr : Array[bool]
	var val = read_int()
	for i in range(bitwidth):
		arr.append((val & 1) > 0)
		val = val >> 1
	return arr
