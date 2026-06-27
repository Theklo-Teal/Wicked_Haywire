extends Dijkstra
class_name xNetwork

## A network is composed of netlists which are isolated graphs. sockets are
## connected by Wires and wires refer to a Port where sockets emit to or receive
## signals from. Ports shared between Wires mean they have a tunnel between them.
## NOTE: Changes to the positioning of objects representing graph nodes should be
## done here to account in indexing Dictionaries and propagate changes throughout
## the affected network graph.

var netlist := xNetData.new()
var graphs : Array[xPort]  ## These are not stored and are reconstructed after Dijkstra mapping.
var changed : Array[xJoint]  ## Joints that have connections changed.

#region Infrastructure Classes
class xNetData extends Resource:
	## We have network elements in here, so they can be serialized and interchanged
	## with loading and saving.
	@export_storage var joints : Dictionary[Vector3i, xJoint]  ## For free standing joints.
	@export_storage var wires : Dictionary[int, Array]  ## An array of xWire for a given layer.
	@export_storage var gizmos : Dictionary[int, Array]  ## An array of xGizmo for a given layer.

class xNetNode extends DijkstraNode:
	pass

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

@abstract class xNetConnect extends Resource:
	#signal propagated(args:Array)  ## Called to handle propagation requests as a coroutine.
	## Anything that can be connected in a network, like sockets
	## and wires.
	@export_storage var dijkstra : xNetNode
	@export_storage var position : Vector2
	func _init() -> void:
		if dijkstra == null:
			dijkstra = xNetNode.new(self)
	@abstract func get_rect() -> Rect2
	## How to draw this object on the [code]canvas[/code].
	@abstract func draw(canvas:Control, highlight:bool=false)
	
	## Called by network propagation to inform of a position change.
	@warning_ignore("unused_parameter")
	func update_position(pos:Vector2, from:xNetConnect=null) -> Array:
		position = pos
		return [position, self]
#endregion

#region Cable Management
## Finds the port of the endpoint joint closest to the wire.
func get_wire_Port(wire:xWire) -> xPort:
	var path = search(wire.dijkstra)
	if path.is_empty(): return null
	return path.back().port

## Update length and corners of a wire according to a new position for the given end.[br]
## This preserves chirality of the wire instance.[br]
## NOTE: When continuously moving, like if dragging with the mouse, only call
## this function at the end of the operation, once comitting to a position.
## Meanwhile use the [code]xWire.draw_*()[/code] functions as if operating on
## a dummy wire to display a preview of the movement operation to the user.
func move_wire_chi(wire:xWire, ending:xWire.VERT, where:Vector2):
	var other : xWire.CORN = (wire.corners[ending] + 2) % 3  as xWire.CORN  # Opposite ending.
	var other_pos = wire.get_verts()[other]
	var new_vec = other_pos - where
	wire.length = new_vec.length()
	var chiral = (wire.corners[0] < wire.corners[2]) != (wire.corners[1] % 2 == 0)
	wire.corners = xWire.get_corners_chi(new_vec, chiral)
	
	var sock = search(wire.dijkstra).back()
	if sock == null: return
	propagate(sock.dijkstra, "update_position", sock.position, sock)

## Update length and cornersof a wire according to a new position for the given end.[br]
## This preserves whether the wire instance starts with a shorter or longer segment.[br]
## NOTE: When continuously moving, like if dragging with the mouse, only call
## this function at the end of the operation, once comitting to a position.
## Meanwhile use the [code]xWire.draw_*()[/code] functions as if operating on
## a dummy wire to display a preview of the movement operation to the user.
func move_wire_len(wire:xWire, ending:xWire.VERT, where:Vector2):
	var other : xWire.CORN = (wire.corners[ending] + 2) % 3  as xWire.CORN  # Opposite ending.
	var other_pos = wire.get_verts()[other]
	var new_vec = other_pos - where
	wire.length = new_vec.length()
	var short = true if wire.get_leg(false) == xWire.VERT.ORIGIN else false
	wire.corners = xWire.get_corners_len(new_vec, short)
	
	var sock = search(wire.dijkstra).back()
	if sock == null: return
	propagate(sock.dijkstra, "update_position", sock.position, sock)
#endregion


#func register_gizmo(gizmo:Node, layer:int=0):
	#netlist.gizmos.append(gizmo)

## Registers and existing joint as part of this network.
func register_joint(joint:xJoint, layer:int, coord:Vector2i):
	netlist.joints[Vector3i(coord.x, coord.y, layer)] = joint
	joint.position = X.from_grid(coord)
	#NOTE: xVia are only connected by tunnel when they are wired to something.

func register_wire(wire:xWire, layer:int):
	var list = netlist.wires.get_or_add(layer, [])
	list.append(wire)
	changed.append_array(wire.ori_conn + wire.end_conn)

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
var regenerate : bool
func graphs_mapped(queries:Array[DijkstraQuery]):
	super(queries)
	
	# Regenerate the simulation network.
	regenerate = true
	for graph in find_graphs(queries, true):
		var port : xPort = null
		for joint : xJoint in graph:
			# Update position of relatively positioned objects.
			if joint.dijkstra.is_target:
				propagate(joint.dijkstra, "update_position", joint.position)
			
			if port == null:
				# Haven't found a port for the graph yet.
				port = joint.port
				if not port in graphs:
					graphs.append(port)
			else:
				# Use an existing port of one of the other nodes in the graph.
				joint.port = port
		if port == null:
			# No port found on any of the joints in the graph.
			port = xPort.new()
			for joint : xJoint in graph:
				joint.port = port
				graphs.append(port)

#endregion

#region Simulation Stuff

func setup_cycle():
	if regenerate:
		# Clean up the Ports list.
		regenerate = false
		var new_graphs : Array[xPort]
		for port : xPort in graphs:
			if port.get_reference_count() > 1:
				# There are more things referencing this port than just in the
				# graphs array, so they are still in use.
				new_graphs.append(port)
		graphs = new_graphs

func cycle_update():
	for layer in netlist.gizmos:
		for g in netlist.gizmos[layer]:
			g.update_cycle()

func finish_cycle():
	for port in graphs:
		port.integrate()
	
	var nodes : Array
	for owner in changed:
		if owner.dijkstra.is_target:
			nodes.append(owner.dijkstra)
	if not nodes.is_empty():
		mapping(nodes)
		changed.clear()
		
#endregion
