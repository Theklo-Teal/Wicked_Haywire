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
	@export_storage var joints : Dictionary[Vector3i, Joint]  ## For free standing joints.
	@export_storage var gizmos : Dictionary[int, Array]  ## An array of Gizmo for a given layer.


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

## Tries to returns an existing joint at [code]where[/code], otherwise registers
## the given joint. Whatever joint is used, is returned.
func get_or_add_joint(where:Vector2, layer:int, added_joint:Joint) -> Joint:
	var cell = X.to_grid(where)
	var joint = netlist.joints.get_or_add(Vector3i(cell.coord.x, cell.coord.y, layer), added_joint)
	joint.position = cell.position
	joint.layer = layer
	return joint
	#NOTE: xVia are only connected by tunnel when they are wired to something. 
	# So we don't get their tunnel name at registering.

func move_joint(joint:Joint, where:Vector2) -> Error:
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
