@tool
extends GizmoSocket
class_name BitInput

func _init() -> void:
	super()
	mode = SINK
	port_class = &"BitPort"
	accepted_port = [&"BitPort"]
