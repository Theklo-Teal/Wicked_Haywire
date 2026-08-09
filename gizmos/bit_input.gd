@tool
extends GizmoSocket
class_name BitInput

func _init() -> void:
	super()
	mode = SINK
	port_class = &"BitPort"
	accepted_port = [&"BitPort"]


## This calls [code]write()[/code] and returns its outcome if the port value has
## changed, otherwise returns [code]null[/code].
func edge_trigger(filter:="none", ...filter_args) -> Variant:
	if port.changed: return read.callv([filter] + filter_args)
	return null
