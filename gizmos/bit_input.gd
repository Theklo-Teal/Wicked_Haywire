@tool
extends GizmoSocket
class_name BitInput

func _init() -> void:
	super()
	mode = SINK
	toggle = true
	port_class = &"BitPort"
	accepted_port = [&"BitPort"]

#func read(filter:="none", ...filter_args) -> Variant:
	#var bitsignal = port.read()
	#var conflict = bitsignal.hiz | (bitsignal.up & bitsignal.down)
	#var agreed = bitsignal.maxval ^ conflict
	#var val = port.read(filter, filter_args)
	#val = val & agreed | conflict
	#_has_read(val)
	#has_read.emit(val)
	#return val
