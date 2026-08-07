extends NetBase.Port
class_name BitPort

static func get_protocol_name() -> Variant:
	return &"BitSignal"
static func get_protocol() -> Variant:
	return Electronics.BitSignal

static func default_link():
	return &"BitCable"

static func default_value() -> Variant:
	return Electronics.BitSignal.new()

func _init() -> void:
	value = default_value()

func _integrate():
	value.width = 1
	for entry : Electronics.BitSignal in aggregate:
		value.width = max(value.width, entry.width)
		value.bits = entry.bits

## Return the boolean state of the bit at the given digit. 0 is the least significant.
func read_bool(data, digit:=0) -> bool:
	return data.to_int() & (1 << digit) == 1

## Return all the bits after accounting Hi-Z and pull states.
func read_int(data) -> int:
	return data.to_int()

## Write a value where all bits are valid, with a given bitwidth. If some bits
## aren't to be set, include a Hi-Z integer.
func write_value(val:int, bitwidth:int=1, hiz:int=0) -> Electronics.BitSignal:
	var data = Electronics.BitSignal.new()
	data.width = bitwidth
	data.bits = val
	data.hiz = hiz
	return data

## Write which bits are pulled high, setting a default state if there are no other connections.
func write_pull_up(mask:int, bitwidth:int=1) -> Electronics.BitSignal:
	var data = Electronics.BitSignal.new()
	data.width = bitwidth
	data.up = mask
	return data

## Write which bits are pulled low, setting a default state if there are no other connections.
func write_pull_down(mask:int, bitwidth:int=1) -> Electronics.BitSignal:
	var data = Electronics.BitSignal.new()
	data.width = bitwidth
	data.down = mask
	return data
