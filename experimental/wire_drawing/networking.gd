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

var ports : Array[xPort]  ## Known Ports
#var changed : Array[xJoint]  ## Joints that have connections changed.

func _init() -> void:
	if netlist == null:
		netlist = xNetData.new()

class xNetData extends Resource:
	## We have network elements in here, so they can be serialized and interchanged
	## with loading and saving.
	@export_storage var joints : Dictionary[Vector3i, xJoint]  ## For free standing joints.


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
func get_or_add_joint(coord:Vector2i, layer:int, new_joint:xJoint) -> xJoint:
	var joint = netlist.joints.get_or_add(Vector3i(coord.x, coord.y, layer), new_joint)
	joint.position = X.from_grid(coord)
	joint.layer = layer
	return joint
#endregion
