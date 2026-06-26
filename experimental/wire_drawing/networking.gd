extends Dijkstra
class_name xNetwork

## A network is composed of netlists which are isolated graphs. sockets are
## connected by Wires and wires refer to a Port where sockets emit to or receive
## signals from. Ports shared between Wires mean they have a tunnel between them.

var netlist := xNetData.new()
var graphs : Array[xPort]  ## These are not stored and are reconstructed after Dijkstra mapping.

class xNetData extends Resource:
	## We have network elements in here, so they can be serialized and interchanged
	## with loading and saving.
	@export_storage var vias : Dictionary[StringName, xVia]
	@export_storage var joints : Dictionary[Vector3i, xJoint]  ## For free standing joints. The key indicates coordinate on the canvas grid, with Z axis being a layer.
	@export_storage var wires : Array[xWire]  ## Two xJoint associated with a wire.
	@export_storage var gizmos : Dictionary[Node, int]  ## int is for layer. Other Joints should be stored in these.

class xNetNode extends DijkstraNode:
	## In this variation of a Dijkstra node, [code]connected[/code] tells a
	## connection without a wire drawn as if this node is the stop of the wire.
	## [code]wires[/code] stores the drawn link to another node as if this is
	## the wire start.
	@export_storage var wired : Dictionary[xJoint, xWire]
	func get_connections(_source_node:DijkstraNode) -> Array[DijkstraNode]:
		var conns : Array[DijkstraNode]
		for joint in wired.keys() + connected:
			conns.append(joint)
		return conns

func register_gizmo(gizmo:Node, layer:int=0):
	netlist.gizmos[gizmo] = layer

func register_joint(where:Vector2i, layer:int, joint:xJoint):
	netlist.joints[Vector3i(where.x, where.y, layer)] = joint
	if joint is xVia:
		netlist.vias[joint.name] = joint

## This registers a connection between two Joints and returns the wire used to
## represent that connection, which parameters can later be adjusted.
func join(start:xJoint, stop:xJoint) -> xWire:
	var wire = xWire.from_chiral(start, stop, false)
	start.dijkstra.wired[stop] = wire
	stop.dijkstra.connected.append(start)
	netlist.wires.append(wire)
	return wire
	#var ori = data.joints.find_key(start)
	#var end = data.joints.find_key(stop)
	#ori = X.from_grid(Vector2i(ori.x, ori.y))
	#end = X.from_grid(Vector2i(end.x, end.y))
	#var wire = xWire.from_chiral(start, stop, false)


#region Get things
#func get_Port(wire:xWire) -> xPort:
	#return list.get(wire)
#func get_Wire(port:xPort) -> Array[xWire]:
	#var found : Array[xWire]
	#for each in list:
		#if list[each] == port:
			#found.append(each)
	#return found
#
### Returns an existing socket or [code]null[/code] if there's none at that coordinate.
#func get_socket(where:Vector2) -> xSocket:
	#var cell = X.to_grid(where)
	#return sockets.get(cell.coord)
#endregion
#region Add Things
## Returns an existing socket or creates one if it doesn't exist at the coordinate.
#func add_socket(where:Vector2) -> xSocket:
	#var cell = X.to_grid(where)
	#return xSocket.new()

#func add_wire(from:xSocket, to:xSocket, short_first:bool=false) -> xWire:
	#var wire = xWire.from_length(from, to, short_first)
	#return wire
	#for query : DijkstraQuery in dijkstra_mapping(from, to):
	#	for socket : xSocket in query.endpoints:
	#		socket in 
	
	#var wire : xWire = from.wire
	#if wire == null:
		#wire = to.wire
	#if wire == null:
		#wire = xWire.new()
		#from.wire = wire
		#to.wire = wire
		#list[wire] = xPort.new()
	#else:
		#from.wire = wire
	#
	#var segm = xWireSegm.from_length(from.position, to.position, short_first)
	#segm.ori_conn.append(from)
	#segm.end_conn.append(to)
	#segm.wire = wire
	#wire.segms.append(segm)
	#wire.rect = wire.rect.merge(segm.get_rect())
	#return segm
#endregion
#region Remove Things
#func delete_sock(s:xSocket) -> Error:
	#var cell = sockets.find_key(s)
	#sockets.erase(cell)
	#return OK
#
#func delete_segm(w:xWire, s:xWireSegm) -> Error:
	### Removes a wire segment from this wire. If the segment isn't found, returns
	### [code]ERR_DOES_NOT_EXIST[/code]. If the wire runs out of segments, it returns
	### [code]ERR_TIMEOUT[/code] and deletes its [code]Port[/code] as a sign to
	### update and eventual deletion of the wire itself.
	#if not s in w.segms:
		#return ERR_DOES_NOT_EXIST
	#w.segms.erase(s)
	#if w.segms.is_empty():
		## Mark for deletion of the wire in the network.
		#list[w] = null
		#return ERR_TIMEOUT
	#return OK
#endregion

#region Graph Stuff

#endregion

#region Simulation Stuff
#func regenerate(...joints):
	#for query : DijkstraQuery in mapping.callv(joints):
		#var port = xPort.new()
		#for dijkstra in query.endpoints:
			#var joint : xJoint = dijkstra.get_meta("dijkstra_node_owner")
			#joint.port = port

#func setup_cycle():
	#var outdated : Array[xJoint]
	#for wire in wires:
		#if wires[wire] == true:
			#outdated.append(wire.ori_conn)
			#outdated.append(wire.end_conn)
	#regenerate.callv(outdated)
#func cycle_update():
	#for cell in sockets:
		#var sock = sockets[cell]
		#sock.prompt()
#func finish_cycle():
	#pass

class xPort:
	var value
	var aggregate : Array
	
	## If the port has no values feeding in, what should it be read as?
	static func default():
		return 0
	func integrate():
		value = aggregate.reduce(func(sum, a):return sum + a, 0)
	func read():
		return value
	func write(val):
		aggregate.append(val)
#endregion
