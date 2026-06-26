extends Container
class_name xGizmo

@export_storage var sockets : Array[xSocket]

func get_connections() -> Array[Dijkstra.DijkstraNode]:
	var conns : Array[Dijkstra.DijkstraNode]
	for each in sockets:
		conns.append_array(get_connections())
	return conns
