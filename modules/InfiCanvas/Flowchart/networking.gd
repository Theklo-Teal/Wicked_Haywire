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
#var changed : Array[Joint]  ## Joints that have connections changed.

func _init() -> void:
	if netlist == null:
		netlist = NetData.new()

class NetData extends Resource:
	## We have network elements in here, so they can be serialized and interchanged
	## with loading and saving.
	@export_storage var joints : Dictionary[int, Joint]  ## Find joint from their hashes.
	@export_storage var links : Dictionary[int, Link]  ## The key is the XOR of hashes of two joints. The value is the Link instance representing that. 
	@export_storage var pairs : Dictionary[int, Array]  ## The link hash according to the joints involved. The order encodes the orientation of the link.
	@export_storage var vias : Dictionary[Vector3i, Joint]  ## For free standing joints.
	@export_storage var gizmos : Dictionary[int, Array]  ## An array of Gizmo for a given layer.
	
	## Produce the hash of a pair of joints.
	func make_link(joint1: Joint, joint2: Joint, link: Link) -> int:
		var j1 = hash(joint1)
		var j2 = hash(joint2)
		# Ensure joints are tracked
		joints[j1] = joint1
		joints[j2] = joint2
		# Get pair hash
		var pair = hash(joint1) ^ hash(joint2)
		# Connect joints
		links[pair] = link
		pairs[pair] = [joint1, joint2]
		return pair
	
	## Given a pair hash, what's the other joint of the pair?[br]
	## Returns [code]null[/code] if the hash is invalid or the joint can't be found.
	func link_of(joint:Joint, pair_hash:int) -> Joint:
		if not pair_hash in links: return null
		return joints.get(hash(joint) ^ pair_hash, null)
	
	## Return all the joints connected to the given one.
	func links_of(joint:Joint) -> Array[Joint]:
		var list : Array[Joint]
		var j_hsh = hash(joint)
		for pair in pairs:
			var other = pair ^ j_hsh
			if other in joints:
				list.append(joints[other])
		return list

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
	for coord in gizmo.sockets:
		var socket = gizmo.sockets[coord]
		netlist.joints[hash(socket)] = socket

## Tries to returns an existing joint at [code]where[/code], otherwise registers
## the given joint. Whatever joint is used, is returned.
func get_or_add_joint(where:Vector2, layer:int, added_joint:Joint) -> Joint:
	var cell = X.to_grid(where)
	var joint = netlist.vias.get_or_add(Vector3i(cell.x, cell.y, layer), added_joint)
	joint.position = cell.position
	joint.layer = layer
	netlist.joints[hash(joint)] = joint
	return joint
	#NOTE: xVia are only connected by tunnel when they are wired to something. 
	# So we don't get their tunnel name at registering.

func move_joint(joint:Joint, where:Vector2) -> Error:
	var from = X.to_grid(joint.position)
	var cell_from = Vector3i(from.coord.x, from.coord.y, joint.layer)
	var to = X.to_grid(where)
	var cell_to = Vector3i(to.coord.x, to.coord.y, joint.layer)
	if cell_to in netlist.vias:
		return ERR_ALREADY_IN_USE
	netlist.vias.erase(cell_from)
	joint.position = to.position
	netlist.vias[cell_to] = joint
	return OK

func linking(j1: Joint, j2: Joint) -> Link:
	var link := Link.new()
	netlist.make_link(j1, j2, link)
	return link
#endregion
