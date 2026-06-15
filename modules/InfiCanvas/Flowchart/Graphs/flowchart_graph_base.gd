extends Resource
class_name FlowchartGraph

## With the graph relationships being stored as a Godot Resource, it is easy to serialize them and make edits to the flowchart persist between exiting and loading the program.

var groups : Dictionary[ String, Array ]  # [name][idx] -> Node; Move together 
var layers : Dictionary[ String, Array ]  # [name][idx] -> Node; Visible together
var nodes : Dictionary[FlowchartNode, Array]  # [Node][idx] -> Sockets
var netlist : Array[Wire]

var bridge : Array[Array]  # Links being bridged by some FlowchartNode.
var reconn : Dictionary[ ChartSocket, Wire ]  # which sockets had their connections changed


func _init():
	pass
func add_node(node):
	var lay = layers.get_or_add("Zero_Layer", [])
	lay.append(node)
	nodes[node] = []
	#for sock in node.sockets:
		#add_socket(sock, node)

#func add_socket(socket, node):
	#if not socket in nodes[node]:
		#nodes[node].append(socket)
	#sockets[socket] = null

# Vertices of a wire
class Vertex:
	var conn : Array[Vertex]
	var position : Vector2
	var flag_rem : bool = false
	#TODO implement diagonals
	
	## Separate vertices connected to this one according to inclination. Returns a Dictionary of arrays of vertices with the keys [code]horizontal[/code], [code]vertical[/code], [code]north[/code], [code]south[/code], etc.
	func get_segments() -> Dictionary[String, Array]:
		var segments := {
			"horiz":[],
			"verti":[],
			"ascen":[],  # Ascending diagonal from right to left
			"desce":[],  # Descending diagonal from right to left
			"north":[],
			"east":[],
			"south":[],
			"west":[],
			"north_east":[],
			"south_east":[],
			"south_west":[],
			"north_west":[],
			}
			
		for c in conn:
			if position == c.position:
				flag_rem = true
			elif position.y == c.position.y:
				segments.horiz.append(c)
				if position.x < c.position.x:
					segments.west.append(c)
				else:
					segments.east.append(c)
			elif position.x == c.position.x:
				segments.verti.append(c)
				if position.y < c.position.y:
					segments.north.append(c)
				else:
					segments.south.append(c)
			else:
				var dir : Vector2 = c.position - position
				if dir.aspect() == 1:
					dir = dir.normalized()
					if dir.x + dir.y == 0:
						segments.ascen.append(c)
					else:
						segments.desce.append(c)
		return segments

## Doubly-Connected Edge List container.
class Wire:
	var family : FlowchartWire
	var link : Link
	var verts : Array[Vertex]
	#var sockets : Dictionary[Vertex, ChartSocket]
	#var tunnels : Dictionary[Vertex, String]
	
	func _init() -> void:
		family = FlowchartWire.new()

#region Link Definitions
var class_link : Dictionary[Script, StringName] 
var link_class : Dictionary[StringName, Script]

## Instantiates a link from a given class_name string.
#NOTE Try using ClassDB for this
#NOTE Try using ProjectSettings.get_global_class_list() for this
func make_link(link_class_name:StringName="Link") -> Link:
	return link_class.get(link_class_name, Link).new()
func get_link_name(link:Link) -> StringName:
	return class_link.get(link.get_script(), "Link")

class Link:
	static var is_graph_link : bool = true  #NOTE This is used to identify the inner classes that are "Link" without having to instantiate them.
	
	var wire : Wire
	var value  ## Current value in the link for reading by sockets.
	var aggregate : Array  ## Append written values during simulation update to then integrate to final decision.
	var default = 0 : get = _get_default
	
	## The default given to connected link.
	func _get_default():
		return default
	## What to give to sockets that would use this type of link, but aren't connected?
	static func unconnected_default():
		return 0
	
	func integrate():
		if aggregate.size() > 0:
			value = _integrate()
			aggregate.clear()
	## At the end of simulation cycle decide what the final value of the link will be given various entries in [code]aggregate[/code].
	func _integrate():
		return value
	
	## Input data for the next state of the link. It returns an error code, if data isn't accepted.[br]
	## Optionally, a write [code]filter[/code] can be specified, which transforms the format of the data before storing. An error is return if the requested filter doesn't exist.
	func write(val, filter:String="filter") -> Error:
		if not has_method("write_" + filter):
			return Error.ERR_DOES_NOT_EXIST
		val = call("write_"+filter, val)
		if val == null:
			return Error.ERR_INVALID_DATA
		aggregate.append(val)
		return Error.OK
	
	## Get current data of the link. Optionally, a read [code]filter[/code] can be specified, which transforms the data that is returned. If the filter doesn't exist, this returns [code]null[/code].
	func read(filter:String="filter"):
		if not has_method("read_" + filter):
			return null
		return call("read_" + filter)
	
	## Tell if the value written to his link is valid or what transformation to do with it. It returns [code]null[/code] if the value wasn't accepted.
	func write_filter(val):
		return val
	## Tell if there should be a transformation to the value read frm this link.
	func read_filter():
		return value

#endregion

#region Networking
## I don't know how a heart is a spade, but somehow a connection is made.[br]
## Queue a socket to have its network updated.
func connect_socket(socket:ChartSocket):
	reconn[socket] = null

## Queue a socket to have its network updated. If [code]tunnel_name[/code] isn't empty, we try removing it from a tunnel.
func disconnect_socket(socket:ChartSocket):
	reconn[socket] = null

## Performs a breadth-first search to return a list of sockets which are connects together according to their wire and tunnel references.
func follow_wires(unchecked : Array[ChartSocket], checked : Array[ChartSocket] = [], tunnels : Array[String] = []) -> Array[ChartSocket]:
	return checked

#region Simulation Handlers
signal sim_cycle_begun
signal sim_cycle_finished

func cycle_begin():
	# Check for new connections in queue and update their networks.
	
	# Deprecate old links
	
	reconn.clear()
	sim_cycle_begun.emit()

func cycle_finish():
	# Commit the new values of links.
	#for wire in netlist:
		#var superaggregate : Array = []
		#for link in netlist[wire]:
			#superaggregate += link.aggregate
			#link.aggregate.clear()
		#netlist[wire][0].aggregate = superaggregate
		#var new_value = netlist[wire].front().integrate()
		#for link in netlist[wire]:
			#link.value = new_value
	sim_cycle_finished.emit()

## Read value of a link in this simulation update cycle. It returns [code]null[/code] if the link referenced in the socket doesn't exist.[br]
## Optionally provide a Link filter name to format the value before returning it.
func read(socket:ChartSocket, filter:String="filter") -> Variant:
	if socket.link == null:  # The socket isn't connected to anything.
		return link_class[socket.link_class].unconnected_default()
	else:
		var val = socket.link.read(filter)
		socket.has_read(val)
		return val

## Write the value of a link for the next simulation update cycle.[br]
## Optionally you may provide a Link filter name to format the value before commiting.[br]
## The actual value that will be stored in the link depends on whether other sockets tried to write at the same cycle and how a link type handles that using the [code]Link.integrate()[/code] function.
func write(socket:ChartSocket, val, filter:String="filter") -> Error:
	var err := socket.link.write(val, filter)
	if err == Error.OK:
		socket.has_written(val)
	return err
#endregion
