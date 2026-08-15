@tool
extends GizmoSocket
class_name BitOutput

## The pressed state indicates the values written to the port are inverted.

@export var bitwidth : int = 1 : 
	set(val):
		bitwidth = clamp(val, 1, 32)

func _init() -> void:
	super()
	mode = SOURCE
	toggle = true
	port_class = &"BitPort"
	accepted_port = [&"BitPort"]


func send(pack:Electronics.BitData):
	if pressed: pack.bits = pack.bits ^ pack.maxval
	write(pack)

func write_int(val:int, hiz:int=0):
	var data = Electronics.BitData.new(bitwidth)
	data.bits = val
	data.hiz = hiz
	send(data)

func write_bool(digit_from:int=0, ...bools):
	var data = Electronics.BitData.new(bitwidth)
	var mask = Electronics.max_val(bools.size()) << digit_from
	data.hiz = data.maxval ^ mask
	var num : int = 0
	for b in bools:
		num = (num << (1 + digit_from)) | int(b)
	data.bits = Electronics.set_bits(data.bits, num, mask)
	send(data)
