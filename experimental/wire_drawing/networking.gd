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
## Updates the positioning and shape of wires adjacent to the given ones.
func update_wiring(wires:Array[xWire], timestamp:int):
	for wire in wires:
		wire.timestamp = timestamp
		for each in wire.ori_conn + wire.end_conn:
			var ending = wire.get_ending(each)
			if each.timestamp == timestamp: continue
			if each.distan < wire.distan: continue
			each.timestamp = timestamp
			if each is xJoint: 
				wire.update_position(each.position, ending)
				continue
			if each is xWire:
				var pos = wire.get_vertex_position(ending)
				ending = each.get_ending(wire)
				each.update_position(pos, ending)

func _joint_wire_accept(curr:xNetNode, next:xNetNode, timestamp:int) -> bool:
	if timestamp == next.timestamp: return false
	if not next is xWire: return false
	if next.distan > 0 and next.distan < curr.distan: return false
	return true

## Updates the positioning and shape of wires that connect to the given joints
## and are within its region.
func update_joints(joints:Array[xJoint], timestamp:int):
	for joint in joints:
		joint.timestamp = timestamp
		var crawl := xCrawler.new([joint])
		while not crawl.is_finished():
			for wire : xWire in crawl.depth_traverse(_joint_wire_accept.bind(timestamp)):
				wire.timestamp = timestamp
				
				var prev = crawl.history[wire as xNetNode]
				wire.endnode = crawl.root[prev]
				
				var wire_ending = wire.get_ending(prev)
				if prev is xJoint:
					wire.update_position(prev.position, wire_ending)
				else:
					var vert_pos = wire.get_vertex_position(wire_ending)
					wire.update_position(vert_pos, wire_ending)
				
				var next_dist = prev.distan + 1
				if wire.distan <= 0:
					wire.distan = next_dist
				else:
					wire.distan = min(next_dist + 1, wire.distan)


func _update_nodes(...changed):
	var endnodes : Array[xJoint]  # Joints that were modified
	var wires : Array[xWire]  # Wires that were modified
	
	for node in changed:
		if node is xJoint:
			endnodes.append(node)
		elif node is xWire:
			wires.append(node)
	
	var timestamp = Time.get_ticks_usec()
	update_wiring(wires, timestamp)
	update_joints(endnodes, timestamp)
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
	var cell_from = Vector3i(from.coord.x, from.coord.y, joint.layer)
	var to = X.to_grid(where)
	var cell_to = Vector3i(to.coord.x, to.coord.y, joint.layer)
	if cell_to in netlist.joints:
		return ERR_ALREADY_IN_USE
	netlist.joints.erase(cell_from)
	joint.position = to.position
	netlist.joints[cell_to] = joint
	return OK
#endregion

#region Handling Wires

## Returns info on the wire under the point [code]where[/code]. The key [code]wire[/code]
## is the wire instance. Refer to [code]xWire.near()[/code] to know other keys.
func over_wire(where:Vector2, layer:int) -> Dictionary:
	for wire : xWire in netlist.wires.get(layer, []):
		if wire.get_rect().has_point(where):
			var info = wire.near(where)
			if not info.is_empty():
				info["wire"] = wire
				return info
	return {}

## Sets a new wire, or updates an existing one by clearing its connections
## at the specified ending, then setting its layer[br]
## Returns any nodes that were disturbed by the modification of a wire.[br]
## By default changes both ends of a wire, but one end my be specified
func _register_wire(wire:xWire, layer:int, ending:=xWire.VERT.MIDDLE) -> Array[xNetNode]:
	var affected : Array[xNetNode] = [wire]
	if netlist.wires.has(wire.layer):
		if wire in netlist.wires[wire.layer]:
			# Already existing wire.
			netlist.wires[wire.layer].erase(wire)
			affected.append_array(wire.clear_connections(ending).keys())
	var wire_list = netlist.wires.get_or_add(layer,[])
	if not wire in wire_list: wire_list.append(wire)
	wire.layer = layer
	return affected


## Connects the given [code]ending[/code] of [code]wire[/code] to a xJoint.
## Anything connected to [code]wire[/code] there will be cleared[br]
func plug_wire(wire:xWire, joint:xJoint, ending:xWire.VERT):
	var old_conns = _register_wire(wire, ending)
	for each in old_conns:
		each.disconnection(wire, true)
	
	wire.connect_ending(ending, joint)
	joint.connected.append(wire)
	#_update_nodes.call_deferred.callv(old_conns)


## Adds [code]to[/code] to [code]from[/code] at the given endings. This preserves any
## connected wires, but not other node types.
func extend_wire(from: xWire, to:xWire, from_ending:xWire.VERT, to_ending:xWire.VERT):
	var from_conns = _register_wire(from, from.layer, from_ending)
	var to_conns = _register_wire(to, from.layer, to_ending)
	var new_from_conns = from_conns.filter(func(a): return a is xWire)
	var new_to_conns = to_conns.filter(func(a): return a is xWire)
	new_from_conns.append(to)
	new_to_conns.append(from)
	netlist.wires.get_or_add(from.layer, []).append(to)
	from.connect_ending.callv([from_ending] + new_from_conns)
	to.connect_ending([to_ending] + new_to_conns)
	#_update_nodes.call_deferred.callv(from_conns + to_conns)

## Break a [code]wire[/code] in two connected wires. The original will still exist,
## but shortened.
func split_wire(wire: xWire, ratio:float, subratio:float):
	var ending = xWire.VERT.ORIGIN if ratio < 0.5 else xWire.VERT.ENDING
	var short = wire.get_segment_is(false) == ending
	var fixed_vert = wire.get_vertex_position((ending + 2) % 4)
	var old_vert = wire.get_vertex_position(ending)
	var split_vert = wire.find_point(subratio)
	var split_conns = wire.clear_connections(ending)
	
	var new_wire = xWire.new()
	new_wire.set_length(split_vert, old_vert, short)
	new_wire.ori_conn.append(wire)
	for each in split_conns:
		new_wire.connect_ending(xWire.VERT.ENDING, each)
		var each_ending = split_conns[each]
		if each_ending == xWire.VERT.MIDDLE:
			each.connected.append(new_wire)
		else:
			each.connect_ending(each_ending, new_wire)
	
	if ending == xWire.VERT.ORIGIN:
		wire.set_length(split_vert, fixed_vert, short)
		wire.ori_conn.append(new_wire)
	elif ending == xWire.VERT.ENDING:
		wire.set_length(fixed_vert, split_vert, short)
		wire.end_conn.append(new_wire)
	
	#_update_nodes.call_deferred.callv([wire, new_wire] + split_conns)

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
