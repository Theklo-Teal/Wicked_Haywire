extends xNetBase
class_name xNetwork

@warning_ignore("unused_signal")
signal connections_changed  ## Whenever the wiring on Joints changes, this is called.

## A network is composed of netlists which are isolated graphs. sockets are
## connected by Wires and wires refer to a Port where sockets emit to or receive
## signals from. Ports shared between Wires mean they have a tunnel between them.
## NOTE: Changes to the positioning of objects representing graph nodes should be
## done here to account in indexing Dictionaries and propagate changes throughout
## the affected network graph.

var netlist := xNetData.new()
var ports : Array[xPort]  ## Known Ports
#var changed : Array[xJoint]  ## Joints that have connections changed.

class xNetData extends Resource:
	## We have network elements in here, so they can be serialized and interchanged
	## with loading and saving.
	@export_storage var joints : Dictionary[Vector3i, xJoint]  ## For free standing joints.
	@export_storage var wires : Dictionary[int, Array]  ## An array of xWire for a given layer.
	@export_storage var gizmos : Dictionary[int, Array]  ## An array of xGizmo for a given layer.


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


#region Graph Stuff
class xCrawler:
	var orig : Array[xNetNode]
	var history : Dictionary[xNetNode, xNetNode]  ## Nodes from which a node in the keys was found from.
	var queue : Array[xNetNode]  ## The traversal queue or stack, where nodes to visit are placed.
	var finds : Array[xNetNode]  ## The items of interest found along the search. It might have duplicates, if the same finding is repeated.
	var iter_finds : Array[xNetNode]  ## The items of interest found on the last search iteration.
	var _head : int  # Pointer of `queue`: nodes behind can't be visited again, ahead are yet to visit.
	var _iter : int  # Pointer of `finds`: Ahead are finds of the last iteration which haven't been returned yet.
	func _init(origins:Array[xNetNode]) -> void:
		orig.assign(origins)
		queue = orig.duplicate()
	
	## In case you want to a search anew, without losing finds so far. It won't clear
	## previous finds, nor history, but it will be overwritten with further iterations.[br]
	## NOTE: This will allow previously visited nodes to be visited again.
	func reset():
		queue = orig.duplicate()
		_head = 0
	
	## Returns whether there are nodes to search, even if they aren't what's being searched.
	func is_finished() -> bool:
		return queue.is_empty() or _head == queue.size() - 1
	
	## From a node in [code]finds[/code], return the chain of nodes back
	## into its search origin. Both the origin and [code]from[/code] are included.
	func path(from:xNetNode) -> Array[xNetNode]:
		var chain : Array[xNetNode] = [from]
		var source = history[from]
		while not source in orig:
			source = history[chain.back()]
			chain.append(chain)
		return chain
	
	## Perform one iteration of the traversal through the graph in
	## depth-first search, returns any novel xNetNode that made
	## [code]node_find()[/code] return true.[br]
	## Provide a [code]node_accept()[/code] function that takes a node and tells
	## whether to continue search from that node. An invalid callable is interpreted
	## as accepting and finding anything.[br]
	## By default "found" nodes might not be "accepted", but you can control that
	## by setting [code]find_also_accept[/code] to [code]true[/code].[br]
	## Returns empty if there are not more nodes to search.
	## You may stop iterating early if a desired end object has been found.
	func depth_search(node_accept:=Callable(), node_find:=Callable(), find_also_accept:=false) -> Array[xNetNode]:
		if queue.is_empty(): return []
		var curr = queue.pop_back()
		var prev = history[curr]
		for conn in curr.get_connections(prev):
			if conn in queue: continue
			var accepted = not node_accept.is_valid or node_accept.call(conn)
			if not node_find.is_valid() or node_find.call(conn):
				if not (find_also_accept and not accepted):  # Have you heard about "imply" boolean operators? This one example.
					finds.append(conn)
			if accepted:
				queue.append(conn)
				history[conn] = prev
				break
		
		iter_finds = finds.slice(_iter, finds.size())
		_iter = finds.size()
		return iter_finds
	
	## Perform one iteration of the traversal through the graph in
	## breadth-first search, returns any novel xNetNode that made
	## [code]node_find()[/code] return true.[br]
	## Provide a [code]node_accept()[/code] function that takes a node and tells
	## whether to continue search from that node. An invalid callable is interpreted
	## as accepting and finding anything.[br]
	## By default "found" nodes might not be "accepted", but you can control that
	## by setting [code]find_also_accept[/code] to [code]true[/code].[br]
	## Returns empty if there are not more nodes to search.
	## You may stop iterating early if a desired end object has been found.
	func breadth_search(node_accept:=Callable(), node_find:=Callable(), find_also_accept:=false) -> Array[xNetNode]:
		var endstop = queue.size()
		for node in queue.slice(_head, endstop):
			for conn in node.get_connections(node):
				if conn in queue: continue
				var accepted = not node_accept.is_valid() or node_accept.call(conn)
				history[conn] = node  # We keep track of the nodes in the path towards a find of interest, not just finds of interest.
				if not node_find.is_valid() or node_find.call(conn):
					if not (find_also_accept and not accepted):  # Have you heard about "imply" boolean operators? This one example.
						finds.append(conn)
				if accepted and not conn in queue:
					queue.append(conn)
		_head = endstop
		iter_finds = finds.slice(_iter, finds.size())
		_iter = finds.size()
		return iter_finds


## Updates the positioning and shape of wires if they were modified.
func update_wiring(wires:Array[xWire], timestamp:int=-1):
	timestamp = Time.get_ticks_usec() if timestamp < 0 else timestamp
	var search_joint = func(a): return a is xJoint
	var search_wire = func(a): return a is xWire and a.timestamp != timestamp
	
	for wire in wires:
		# Find the closest Joint to each wire.
		var crawl := xCrawler.new([wire as xNetNode])
		while crawl.breadth_search(Callable(), search_joint).is_empty() and not crawl.is_finished():
			#NOTE This is fine to do, because the loop will stop once something
			# is found and we want whatever is found first.
			continue
		if crawl.finds.size() <= 1:
			# Nothing was found.
			continue
		# Update positions up to "wire".
		var path = crawl.path(crawl.finds[0])  # If there happen to be multiple xJoints, select just one of them to avoid competing paths to the same wire target.
		var last = path.pop_back()  # The first path element should be an xJoint.
		var port : xPort = last.port
		var chain_pos = last.position
		var conn_ending = path.back().get_ending(last)  # Ending where the connection happens.
		while not path.is_empty():
			if conn_ending == xWire.VERT.MIDDLE: break  # Some funny connection that can't be replicated.
			var conn = path.back()
			conn.port = port
			chain_pos = conn.update_position(chain_pos, conn_ending)
			conn_ending = conn.get_ending(last)
			last = path.pop_back()
		
		# Update positions from wire onwards
		crawl.reset()
		var wire_pos = wire.get_vertex_position(wire.get_ending(last, true))  # Keep track of the position of the forward ending of "wire" because we'll be reusing it for the chain of each connection in that direction.
		while not crawl.depth_search(search_wire).is_empty() and not crawl.is_finished():
			for node in crawl.iter_finds:
				node.timestamp = timestamp
				node.port = port
				if node is xWire:
					if conn_ending == xWire.VERT.MIDDLE: break  # Some funny connection that can't be replicated.
					if node in wire.ori_conn + wire.end_conn:
						# Reset chain position when switching to another fork on the road.
						chain_pos = wire_pos
					chain_pos = node.update_position(chain_pos, conn_ending)
					conn_ending = node.get_ending(last)
					last = node

## Updates the positioning and shape of wires that connect to modified sockets.
func update_joints(joints:Array[xJoint], timestamp:int=-1):
	timestamp = Time.get_ticks_usec() if timestamp < 0 else timestamp
	var search_wire = func(a): return a is xWire and a.timestamp != timestamp
	
	for joint in joints:
		var crawl = xCrawler.new([joint as xNetNode])
		var chain_pos = joint.position
		var last = joint
		var conn_ending : xWire.VERT
		while not crawl.breadth_search(search_wire).is_empty():
			for node in crawl.iter_finds:
				node.timestamp = timestamp
				node.port = joint.port
				if node is xWire:
					conn_ending = node.get_ending(last, true)
					chain_pos = node.update_position(chain_pos, conn_ending)

func _update_nodes(...changed):
	var timestamp = Time.get_ticks_usec()
	var endnodes : Array[xJoint]  # Joints that were modified
	var wires : Array[xWire]  # Wires that were modified
	
	for node in changed:
		node.timestamp = timestamp
		if node is xJoint:
			endnodes.append(node)
		elif node is xWire:
			wires.append(node)
	
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
			info["wire"] = wire
			return info
	return {}

## Sets a new wire, or updates an existing one by it clearing its connections
## and reconnect to new targets.[br]
## Returns any nodes that were disturbed by the modification of a wire.[br]
## By default changes both ends of a wire, but one end my be specified
func _register_wire(wire:xWire, layer:int, ending:=xWire.VERT.MIDDLE) -> Array[xNetNode]:
	var affected : Array[xNetNode]
	if netlist.wires.has(wire.layer):
		if wire in netlist.wires[wire.layer]:
			# Already existing wire.
			netlist.wires.erase(wire)
			if ending == xWire.VERT.MIDDLE or ending == xWire.VERT.ORIGIN:
				affected.append_array(wire.clear_start_conns())
			if ending == xWire.VERT.MIDDLE or ending == xWire.VERT.ENDING:
				affected.append_array(wire.clear_stop_conns())
	var wire_list = netlist.wires.get_or_add(layer,[])
	wire_list.append(wire)
	wire.layer = layer
	return affected

## Connects the Origin of [code]wire[/code] to a joint.[br]
func pull_wire(wire:xWire, start:xJoint, layer:int):
	var affected : Array[xNetNode] = [wire]
	affected.append_array( _register_wire(wire, layer, xWire.VERT.ORIGIN) )
	wire.layer = layer
	wire.ori_conn.append(start)
	_update_nodes.callv(affected)

## Connects the Ending of [code]wire[/code] to a joint.[br]
## If using an existing wire, it clears its connections and reconnects to new targets.
func push_wire(wire: xWire, stop:xJoint, layer:int):
	pass

## Add new wire to the end of another
func extend_wire(from: xWire, to:xWire):
	pass

## Add new wire to the start of another
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




#region Add Things
#func register_gizmo(gizmo:Node, layer:int=0):
	#netlist.gizmos.append(gizmo)

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
