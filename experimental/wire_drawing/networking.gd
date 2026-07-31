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

var netlist : xNetData

#var changed : Array[xJoint]  ## Joints that have connections changed.

func _init() -> void:
	if netlist == null:
		netlist = xNetData.new()

class xNetData extends Resource:
	## We have network elements in here, so they can be serialized and interchanged
	## with loading and saving.
	@export_storage var vias : Dictionary[Vector2i, xJoint]  ## For free standing joints.
	@export_storage var joints : Dictionary[int, xJoint]
	@export_storage var pairs : Dictionary[int, Array]
	@export_storage var links : Dictionary[int, xWire]


## Return the joints the given one leads to. Optionally you may select whether to
## get only those originating [code]joint[/code] or ending in it.
func get_connections(joint:xJoint, outgoing:=true, ingoing:=true) -> Array[xJoint]:
	var conns : Array[xJoint]
	var id = hash(joint)
	for pair in netlist.links:
		var other = pair ^ id
		if other in netlist.joints:
			if (netlist.pairs[pair][0] == joint and outgoing) or \
			(netlist.pairs[pair][1] == joint and ingoing):
				conns.append(netlist.joints[other])
	return conns

## Return the pair hashes of connections to the given joint. Optionally you may
## select whether to get only those originating [code]joint[/code] or ending in it.
func get_links(joint:xJoint, outgoing:=true, ingoing:=true) -> PackedInt32Array:
	var conns : PackedInt32Array
	var id = hash(joint)
	for pair in netlist.links:
		var other = pair ^ id
		if other in netlist.joints:
			if (netlist.pairs[pair][0] == joint and outgoing) or \
			(netlist.pairs[pair][1] == joint and ingoing):
				conns.append(pair)
	return conns


func get_or_add_joint(coord:Vector2i, new_joint:xJoint) -> xJoint:
	if coord in netlist.vias:
		return netlist.vias[coord]
	
	netlist.vias[coord] = new_joint
	new_joint.coord = coord
	
	var id = hash(new_joint)
	netlist.joints[id] = new_joint
	return new_joint

func rem_joint_at(coord:Vector2i):
	var joint = netlist.vias.get(coord)
	if joint == null: return
	rem_joint(joint)
	
func rem_joint(joint:xJoint):
	var conns = get_links(joint)
	var id = hash(joint)
	netlist.vias.erase(joint.coord)
	netlist.joints.erase(id)
	for pair in conns:
		netlist.links.erase(pair)
		netlist.pairs.erase(pair)

func pair_hash(j1:xJoint, j2:xJoint) -> int:
	return hash(j1) ^ hash(j2)

func make_link(j1:xJoint, j2:xJoint, link:xWire):
	var pair = pair_hash(j1, j2)
	netlist.pairs[pair] = [j1, j2]
	netlist.links[pair] = link

func rem_link_joints(j1:xJoint, j2:xJoint):
	rem_link_hash(pair_hash(j1, j2))

func rem_link_hash(pair:int):
	netlist.pairs.erase(pair)
	netlist.links.erase(pair)
