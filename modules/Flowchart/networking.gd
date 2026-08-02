extends NetAnalysis
class_name FlowchartNetwork

## A network is composed of netlists which are isolated graphs. sockets are
## connected by Wires and wires refer to a Port where sockets emit to or receive
## signals from. Ports shared between Wires mean they have a tunnel between them.
## NOTE: Changes to the positioning of objects representing graph nodes should be
## done here to account in indexing Dictionaries and propagate changes throughout
## the affected network graphs.

@export var netlist : NetData

var ports : Array[Port]  ## Known Ports
#var changed : Array[NetVert]  ## Joints that have connections changed.

func _init() -> void:
	if netlist == null:
		netlist = NetData.new()

#region Simulation Stuff

var regenerate : bool
func cycle_begin():
	if regenerate:
		# Clean up the Ports list.
		regenerate = false
		var new_ports : Array[Port]
		for port : Port in ports:
			if port.get_reference_count() > 1:
				# There are more things referencing this port than just in the
				# ports array, so they are still in use.
				new_ports.append(port)
		ports = new_ports

func cycle_update():
	for layer in netlist.gizmos:
		for g in netlist.gizmos[layer]:
			g.update_cycle()

func cycle_finish():
	for port in ports:
		port.integrate()
#endregion


#region Graph Editing Stuff

func register_gizmo(gizmo:FlowchartGizmo, layer:int):
	netlist.gizmos.get_or_add(layer, []).append(gizmo)
	for coord in gizmo._sockdex:
		var socket = gizmo._sockdex[coord]
		netlist.verts[hash(socket)] = socket
		netlist.sockets[socket] = gizmo

#TODO Remove Gizmo, unregistering its sockets
func unregister_gizmo(gizmo:FlowchartGizmo, layer:int):
	netlist.gizmos[layer].erase(gizmo)
	if netlist.gizmos[layer].is_empty(): netlist.gizmos.erase(layer)
	for socket in gizmo.sockets:
		rem_vert(socket)

## Tries to returns an existing vertex at [code]where[/code], otherwise registers
## the given vertex. Whatever vertex is used, is returned.
func get_or_add_vert(where:Vector2, layer:int, added_vert:NetVert) -> NetVert:
	var cell = Flowchart.to_grid(where)
	var vert = netlist.vias.get_or_add(Vector3i(cell.x, cell.y, layer), added_vert)
	vert.coord = cell
	vert.layer = layer
	netlist.verts[hash(vert)] = vert
	return vert
	#NOTE: Via are only connected by tunnel when they are wired to something. 
	# So we don't get their tunnel name at registering.

func rem_vert(vert:NetVert):
	var vert_id = hash(vert)
	netlist.verts.erase(vert_id)
	
	for link in netlist.get_links(vert):
		netlist.pairs.erase(link)
		netlist.links.erase(link)
	
	if vert is GizmoSocket:
		netlist.sockets.erase(vert)
	else:
		netlist.vias.erase(Vector3i(vert.coord.x, vert.coord.y, vert.layer))
		

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

func linking(v1: NetVert, v2: NetVert) -> Link:
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

#endregion
