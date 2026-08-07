@tool
extends GizmoSocket
class_name BitOutput

func _init() -> void:
	super()
	mode = SOURCE
	port_class = &"BitPort"
	accepted_port = [&"BitPort"]
