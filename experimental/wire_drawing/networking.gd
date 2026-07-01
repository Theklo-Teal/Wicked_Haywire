extends Dijkstra
class_name xNetwork

signal connections_changed  ## Whenever the wiring on Joints changes, this is called.

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

class xNetNode extends Dijkstra.DijkstraNode:
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
																																																																																																																																																						 
@abstract class xConnectable extends Resource:
	#signal propagated(args:Array)  ## Called to handle propagation requests as a coroutine.
	## Anything that can be connected in a network, like sockets
	## and wires.
	@export_storage var dijkstra : xNetNode
	@export_storage var position : Vector2
	@export_storage var layer : int
	func _init() -> void:
		if dijkstra == null:
			dijkstra = xNetNode.new(self)
		
	@abstract func get_rect() -> Rect2
	## How to draw this object on the [code]canvas[/code].
	@abstract func draw(canvas:Control, highlight:bool=false)
	
	## Called by network propagation to inform of a position change.
	@warning_ignore("unused_parameter")
	func update_position(pos:Vector2, from:xConnectable=null) -> Array:
		position = pos
		return [position, self]

class xCombiner extends xConnectable:
	## It concatenates, joins or splits, the data of multiple sources.
	
	var vertical : bool = false  # Orientation hint
	var positive : bool = true  # Orientation hint
	var ascending : bool = true  # Orientation hint
	var root : Vector2
	var branch_count : int = 4
	var converge : xConnectable
	var branches : Array[xConnectable]
	
	func _init() -> void:
		super()
		dijkstra.is_target = true
	
	func get_rect() -> Rect2:
		var width = branch_count * X.CELL_DIA + X.CLEARANCE
		var size = Vector2.ONE * width
		size[not vertical as int] = X.CELL_DIA + X.CLEARANCE
		var pos = size - root
		return Rect2(pos, size)
		
	func draw(canvas:Control, highlight:bool=false):
		var rect = get_rect()
		canvas.draw_rect(rect, [Color.DARK_SLATE_GRAY, Color.DARK_SEA_GREEN][highlight as int])
		canvas.draw_circle(rect.pos + root, X.CELL_RAD, Color.BLACK)
		for i in range(branch_count):
			var where = rect.pos[vertical as int] + X.CELL_DIA + X.CLEARANCE * i
			canvas.draw_circle(where, X.CELL_RAD, Color.WHITE)
		
#endregion

#region Cable Management
## Finds the port of the endpoint joint closest to the wire.
func get_wire_Port(wire:xWire) -> xPort:
	var path = travel(wire.dijkstra)
	if path.is_empty(): return null
	return path.back().port

## Returns info on the wire under the point [code]where[/code]. The key [code]wire[/code]
## is the wire instance. Refer to [code]xWire.near()[/code] to know other keys.
func over_wire(where:Vector2, layer:int) -> Dictionary:
	for wire : xWire in netlist.wires[layer]:
		if wire.get_rect().has_point(where):
			var info = wire.near(where)
			info["wire"] = wire
			return info
	return {}

## Connects the start of [code]wire[/code] to a joint.[br]
## If using an existing wire, it clears its connections and reconnects to new targets.
func pull_wire(wire:xWire, start:xJoint, layer:int):
	var affected : Array[xConnectable] = [wire]
	var wire_list = netlist.wires.get_or_add(layer,[])
	if netlist.wires.has(wire.layer):
		if wire in netlist.wires[wire.layer]:
			# Already existing wire.
			netlist.wires.erase(wire)
			affected.append_array(wire.clear_start_conns())
	wire_list.append(wire)
	wire.layer = layer
	wire.ori_conn.append(start)
	wire.dijkstra.connected.append(start.dijkstra)
	start.dijkstra.connected.append(wire.dijkstra)
	changed.append_array(affected)

## Connects the stop of [code]wire[/code] to a joint.[br]
## If using an existing wire, it clears its connections and reconnects to new targets.
func push_wire(wire: xWire, stop:xJoint, layer:int):
	var affected : Array[xConnectable] = [wire]
	var wire_list = netlist.wires.get_or_add(layer,[])
	if netlist.wires.has(wire.layer):
		if wire in netlist.wires[wire.layer]:
			# Already existing wire.
			netlist.wires.erase(wire)
			affected.append_array(wire.clear_stop_conns())
	wire_list.append(wire)
	wire.layer = layer
	wire.end_conn.append(stop)
	wire.dijkstra.connected.append(stop.dijkstra)
	stop.dijkstra.connected.append(wire.dijkstra)
	changed.append_array(affected)

## Add new wire to the end of another
func extend_wire(from: xWire, to:xWire):
	pass

## Add new wire to the start of another
func join_wire(from: xWire, to:xWire):
	pass

## Break a wire in two and add the start of a new wire to the meeting point.
func split_wire(from: xWire, to:xWire):
	pass

## Break a wire in to and add the stop of a new wire to the meeting point.
func incise_wire(from: xWire, to:xWire):
	pass


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
	
	var sock = travel(wire.dijkstra).back()
	if sock == null: return
	propagate_fore(sock.dijkstra, "update_position", sock.position, sock)

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
	
	var sock = travel(wire.dijkstra).back()
	if sock == null: return
	propagate_fore(sock.dijkstra, "update_position", sock.position, sock)
#endregion

#func register_gizmo(gizmo:Node, layer:int=0):
	#netlist.gizmos.append(gizmo)

## Tries to returns an existing joint at [code]where[/code], otherwise registers
## the given joint. Whatever joint is used, is returned.
func get_or_add_joint(where:Vector2, layer:int, added_joint:xJoint) -> xJoint:
	var cell = X.to_grid(where)
	var joint = netlist.joints.get_or_add(Vector3i(cell.coord.x, cell.coord.y, layer), added_joint)
	joint.position = cell.position
	joint.layer = layer
	return joint
	#NOTE: xVia are only connected by tunnel when they are wired to something. 
	# So we don't get their tunnel name at registering.

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
	
	#var outdated_endpoints : Array[DijkstraNode]
	#for owner in changed:
		#if owner.dijkstra.is_target:
			#outdated_endpoints.append(owner.dijkstra)
	#if not changed.is_empty():
		#mapping.callv(outdated_endpoints)
		#changed.clear()
		#connections_changed.emit()
		
#endregion
