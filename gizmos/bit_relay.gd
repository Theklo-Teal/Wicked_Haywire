@tool
extends GizmoSocket
class_name BitRelay

func _init() -> void:
	super()
	mode = BIDIR
	port_class = &"BitPort"
	accepted_port = [&"BitPort"]

func bridge(other_port:NetBase.Port, bitmask:int, shift:int = 0):
	pass
