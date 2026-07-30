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


#region Graph Editing Stuff
func get_or_add_joint(coord:Vector2i, new_joint:xJoint) -> xJoint:
	if coord in netlist.vias:
		return netlist.vias[coord]
	
	netlist.vias[coord] = new_joint
	new_joint.coord = coord
	
	var id = hash(new_joint)
	netlist.joints[id] = new_joint
	return new_joint

func make_link(j1:xJoint, j2:xJoint, link:xWire):
	var pair = hash(j1) ^ hash(j2)
	netlist.pairs[pair] = [j1, j2]
	netlist.links[pair] = link

#endregion
