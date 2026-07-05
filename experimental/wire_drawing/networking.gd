extends xNetAnalysis
class_name xNetwork

## A network is composed of netlists which are isolated graphs. sockets are
## connected by Wires and wires refer to a Port where sockets emit to or receive
## signals from. Ports shared between Wires mean they have a tunnel between them.
## NOTE: Changes to the positioning of objects representing graph nodes should be
## done here to account in indexing Dictionaries and propagate changes throughout
## the affected network graphs.

@warning_ignore("unused_signal")
signal connections_changed  ## Whenever the wiring on Joints changes, this is called.

var netlist : xNetData :
	set(val):
		netlist = val
		if val != null and not val.is_empty():
			# Update network flow fields to ensure integrity.
			build_flow_field(val.joints.values())

var ports : Array[xPort]  ## Known Ports
#var changed : Array[xJoint]  ## Joints that have connections changed.

func _init() -> void:
	if netlist == null:
		netlist = xNetData.new()

class xNetData extends Resource:
	## We have network elements in here, so they can be serialized and interchanged
	## with loading and saving.
	@export_storage var joints : Dictionary[Vector3i, xJoint]  ## For free standing joints.
	@export_storage var wires : Dictionary[int, Array]  ## An array of xWire for a given layer.
	@export_storage var gizmos : Dictionary[int, Array]  ## An array of xGizmo for a given layer.
	
	func is_empty() -> bool:
		return joints.is_empty() and wires.is_empty()


#region Simulation Stuff

var regenerate : bool
func setup_cycle():
	if regenerate:
		# Clean up the Ports list.
		regenerate = false
		var new_ports : Array[xPort]
		for port : xPort in ports:
			if port.get_reference_count() > 1:
				# There are more things referencing this port than just in the
				# ports array, so they are still in use.
				new_ports.append(port)
		ports = new_ports

func cycle_update():
	for layer in netlist.gizmos:
		for g in netlist.gizmos[layer]:
			g.update_cycle()

func finish_cycle():
	for port in ports:
		port.integrate()
#endregion


#region Graph Editing Stuff
## Updates the positioning and shape of wires in the path of this one.
func update_wiring(wires:Array[xWire]):
	var accept := Callable(func(curr, next, back): return curr != back and next.distan > curr.distan and next is xWire)
	for wire in wires:
		var orig_path = flow_search(wire)
		var back_neigh : xNetNode
		var last_pos : Vector2
		if orig_path.size() > 1:
			back_neigh = orig_path[-2]
			if back_neigh is xJoint: last_pos = back_neigh.position
			elif back_neigh is xWire:
				var ending = back_neigh.get_ending(wire)
				last_pos = back_neigh.get_vertex_position(ending)
			wire.update_position(last_pos, wire.get_ending(back_neigh))
		var fore_crawl = xCrawler.new([wire as xNetNode])
		while not fore_crawl.is_finished():
			for node : xWire in fore_crawl.depth_traverse(accept.bind(back_neigh), accept.bind(back_neigh)):
				last_pos = node.update_position(last_pos, node.get_ending(fore_crawl.history[node]))	

## Updates the positioning and shape of wires that connect to the given joints.
func update_joints(joints:Array[xJoint]):
	pass

func _update_nodes(...changed):
	var endnodes : Array[xJoint]  # Joints that were modified
	var wires : Array[xWire]  # Wires that were modified
	
	for node in changed:
		if node is xJoint:
			endnodes.append(node)
		elif node is xWire:
			wires.append(node)
	
	update_wiring(wires)
	update_joints(endnodes)
#endregion

#region Handling Joints
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

func move_joint(joint:xJoint, where:Vector2) -> Error:
	var from = X.to_grid(joint.position)
	var cell_from = Vector3i(from.x, from.y, joint.layer)
	var to = X.to_grid(where)
	var cell_to = Vector3i(to.x, to.y, joint.layer)
	netlist.joints.erase(cell_from)
	if cell_to in netlist.joints:
		return ERR_ALREADY_IN_USE
	joint.position = where
	netlist.joints[cell_to] = joint
	return OK
#endregion

#region Handling Wires

## Returns info on the wire under the point [code]where[/code]. The key [code]wire[/code]
## is the wire instance. Refer to [code]xWire.near()[/code] to know other keys.
func over_wire(where:Vector2, layer:int) -> Dictionary:
	for wire : xWire in netlist.wires[layer]:
		if wire.get_rect().has_point(where):
			var info = wire.near(where)
			if not info.is_empty():
				info["wire"] = wire
				return info
	return {}

## Sets a new wire, or updates an existing one by it clearing its connections
## and reconnect to new targets.[br]
## Returns any nodes that were disturbed by the modification of a wire.[br]
## By default changes both ends of a wire, but one end my be specified
func _register_wire(wire:xWire, layer:int, ending:=xWire.VERT.MIDDLE) -> Array[xNetNode]:
	var affected : Array[xNetNode] = [wire]
	if netlist.wires.has(wire.layer):
		if wire in netlist.wires[wire.layer]:
			# Already existing wire.
			netlist.wires[wire.layer].erase(wire)
			affected.append_array(wire.clear_connections(ending))
	var wire_list = netlist.wires.get_or_add(layer,[])
	if not wire in wire_list: wire_list.append(wire)
	wire.layer = layer
	return affected

## Connects the given [code]ending[/code] of [code]wire[/code] to a xJoint.[br]
func plug_wire(wire:xWire, joint:xJoint, ending:xWire.VERT, layer:int):
	var old_conns = _register_wire(wire, layer, ending)
	var affected : Array[xNetNode] = [wire]
	affected.append_array(old_conns)
	wire.connect_ending(ending, joint)
	wire.distan = 1
	wire.endnode = joint
	joint.connected.append(wire)
	_update_nodes.callv(affected)

## Adds [code]to[/code] to [code]from[/code] at the given endings. This preserves any
## connected wires, but not others.
func extend_wire(from: xWire, to:xWire, from_ending:xWire.VERT, to_ending:xWire.VERT):
	var from_preserve : Array[xNetNode] = [to]
	var to_preserve : Array[xNetNode] = [from]
	var affected : Array[xNetNode] = [from, to]
	var from_conns = _register_wire(from, from.layer, from_ending)
	var to_conns = _register_wire(to, from.layer, to_ending)
	affected.append_array(from_conns + to_conns)
	to.endnode = from.endnode
	for each in from_conns:
		if each is xWire: from_preserve.append(each)
	for each in to_conns:
		if each is xWire: to_preserve.append(each)
	from.connect_ending.callv([from_ending] + from_preserve)
	to.connect_ending.callv([to_ending] + to_preserve)
	_update_nodes.callv(affected)


func join_wire(from: xWire, to:xWire):
	pass

## Break a wire in two and add the start of a new wire to the meeting point.
func split_wire(from: xWire, to:xWire):
	pass

## Break a wire in two and add the stop of a new wire to the meeting point.
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

## Update length and corners of a wire according to a new position for the given end.[br]
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

#endregion
