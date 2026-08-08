extends NetUtilities
class_name FlowchartNetwork

## A network is composed of netlists which are isolated graphs. sockets are
## connected by Wires and wires refer to a Port where sockets emit to or receive
## signals from. Ports shared between Wires mean they have a tunnel between them.
## NOTE: Changes to the positioning of objects representing graph nodes should be
## done here to account in indexing Dictionaries and propagate changes throughout
## the affected network graphs.

@export var netlist : NetData : 
	set(val):
		if val == null: return
		netlist = val
		rebuild_network()

func _init() -> void:
	super()
	if netlist == null:
		netlist = NetData.new()

## Propagate a new port from the given verts throughout their whole graphs. Optionally use
## A given common port instead.
func update_ports(port:Port=null, ...vertices):
	var verts : Array[NetVert]
	verts.assign(vertices)
	for each in verts:
		each.port = port if port != null else port_new(each.port_class)
	var crawl = Crawler.new(netlist, verts)
	while not crawl.breadth_traverse().is_empty():
		for each : NetVert in crawl.iter_finds:
			each.port = port if port != null else crawl.root[each].port

## Search the whole [code]netlist[/code] to figure out [code]ports[/code].
func rebuild_network():
	print("Rebuilding Network")
	update_ports.callv([null] + netlist.sockets.keys())

#region Simulation Stuff
signal sim_update_done
signal sim_cycle_begun
signal sim_cycle_finished
signal sim_reset

var sim_ticks : int = 0  ## How many sim update cycles since the start of the application. It will rollover if the value goes past 64 bits.

func reset_simulation():
	rebuild_network()
	sim_reset.emit()

func sim_cycle_begin():
	_sim_cycle_begin()
	sim_cycle_begun.emit()
func sim_cycle_update():
	sim_ticks += 1
	for layer in netlist.gizmos:
		for gizmo : FlowchartPanel in netlist.gizmos[layer]:
			gizmo.sim_update(self)
			await gizmo.sim_update_done
	sim_update_done.emit()
func sim_cycle_finish():
	_sim_cycle_finish()
	sim_cycle_finished.emit()

func _sim_cycle_begin():
	pass
func _sim_cycle_finish():
	pass

func port_new(port_name:StringName) -> Port:
	var port = port_classes[port_name].new()
	sim_cycle_begun.connect(port.sim_cycle_begin.bind(self), CONNECT_PERSIST)
	sim_update_done.connect(port.sim_update.bind(self), CONNECT_PERSIST)
	sim_cycle_finished.connect(port.sim_cycle_finish.bind(self), CONNECT_PERSIST)
	sim_reset.connect(port.reset, CONNECT_PERSIST)
	return port
func link_new(link_name:StringName) -> Port:
	return link_classes[link_name].new()
#endregion


#region Graph Editing Stuff

func register_gizmo(gizmo:FlowchartPanel, layer:int):
	netlist.gizmos.get_or_add(layer, []).append(gizmo)
	gizmo.layer = layer
	if gizmo.get("sockets") == null: return
	for coord in gizmo._sockdex:
		var socket = gizmo._sockdex[coord]
		socket.port = port_new(socket.port_class)
		netlist.verts[hash(socket)] = socket
		netlist.sockets[socket as NetVert] = gizmo

func unregister_gizmo(gizmo:FlowchartPanel, layer:int):
	netlist.gizmos[layer].erase(gizmo)
	if netlist.gizmos[layer].is_empty(): netlist.gizmos.erase(layer)
	for socket in gizmo.sockets:
		rem_vert(socket)

## Tries to returns an existing vertex at [code]where[/code], otherwise registers
## the given vertex. Whatever vertex is used, is returned.
func get_or_add_vert(where:Vector2, layer:int, added_vert:NetVert) -> NetVert:
	var cell = Flowchart.to_grid(where, true)
	var vert = netlist.vias.get_or_add(Vector3i(cell.x, cell.y, layer), added_vert)
	vert.coord = cell
	vert.layer = layer
	netlist.verts[hash(vert)] = vert
	return vert
	#NOTE: Via are only connected by tunnel when they are wired to something. 
	# So we don't get their tunnel name at registering.

func move_vert(vert:NetVert, where:Vector2) -> Error:
	if vert is GizmoSocket: return ERR_INVALID_PARAMETER
	var cell_from = Vector3i(vert.coord.x, vert.coord.y, vert.layer)
	var to = Flowchart.to_grid(where)
	var cell_to = Vector3i(to.coord.x, to.coord.y, vert.layer)
	if cell_to in netlist.vias:
		return ERR_ALREADY_IN_USE
	netlist.vias.erase(cell_from)
	vert.coord = to.coord
	netlist.vias[cell_to] = vert
	return OK

func rem_vert(vert:NetVert):
	var vert_id = hash(vert)
	
	for link in netlist.get_links(vert):
		var other = netlist.verts[link ^ vert_id]
		other.disconnected(vert)
		unlink_verts(vert, other)
	
	netlist.verts.erase(vert_id)
	if vert is GizmoSocket:
		netlist.sockets.erase(vert)
	else:
		netlist.vias.erase(Vector3i(vert.coord.x, vert.coord.y, vert.layer))

func linking(v1: NetVert, v2: NetVert) -> Link:
	if v1.port == null:
		update_ports(v2.port, v1)
	elif v2.port != v1.port:
		update_ports(v1.port, v2)
	
	var pair = make_pair_hash(v1, v2)
	netlist.pairs[pair] = [v1, v2]
	netlist.links[pair] = Link.new()
	v1.connecter(v2)
	v2.connectee(v1)
	return netlist.links[pair]

func unlink_verts(v1:NetVert, v2:NetVert):
	unlink_hash(make_pair_hash(v1, v2))

func unlink_hash(pair_hash:int):
	if not pair_hash in netlist.links: return
	var conns = netlist.pairs[pair_hash]
	netlist.links.erase(pair_hash)
	netlist.pairs.erase(pair_hash)
	conns[0].disconnected(conns[1])
	conns[1].disconnected(conns[0])
	update_ports(null, conns[1])
	if conns[0] is FlowchartVia and conns[0].conns() == 0 and conns[0].text.is_empty: rem_vert(conns[0])
	if conns[1] is FlowchartVia and conns[1].conns() == 0 and conns[1].text.is_empty: rem_vert(conns[1])

#endregion
