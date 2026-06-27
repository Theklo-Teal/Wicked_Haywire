extends Container
class_name xGizmo

@export_storage var sockets : Array[xSocket]
var layer : int = 0

func get_connections() -> Array[Dijkstra.DijkstraNode]:
	var conns : Array[Dijkstra.DijkstraNode]
	for each in sockets:
		conns.append_array(get_connections())
	return conns

func update_cycle():
	pass
	#var val = socket[0].port.read()
	#val += 1
	#socket[1].port.write(val)
