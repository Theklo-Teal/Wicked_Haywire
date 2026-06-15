extends FlowchartWire

func _init() -> void:
	color = Color.WEB_GRAY

## A wire that dynamically changes to that of the first FlowchartSocketSource found in the network.
func get_color(socket:FlowchartSocket=null, graph:FlowchartGraph=null) -> Color:
	if socket == null or graph == null:
		return color
	else:
		var source_socket = graph.find_socket_further(socket, "FlowchartSocketSource")
		if source_socket == null:
			return socket.color
		else:
			return source_socket.color
