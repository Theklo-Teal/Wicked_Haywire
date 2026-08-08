@abstract
extends Node
class_name NetBase

## Definition of classes necessary to build a network.


#region Index Port and Link Classes.
var port_classes : Dictionary[StringName, Script]
var link_classes : Dictionary[StringName, Script]

func _init() -> void:
	@warning_ignore("static_called_on_instance")
	var all_classes = G.list_classes()
	for klaso in all_classes:
		var info = all_classes[klaso]
		if info.added == &"Port":
			port_classes[klaso] = info.script
		elif info.added == &"Link":
			link_classes[klaso] = info.script
#endregion

class Port:
	## Target for signals being conveyed during simulation using an Observer Pattern.
	
	var value  ## Current value in the link for reading by sockets.
	var aggregate : Array  ## Append written values during simulation update to then integrate to final decision.
	
	static func added_class_info() -> StringName:
		return &"Port"
	
	## Return the name of the class defining the data protocol expected by this Port.
	static func get_protocol_name() -> Variant:
		return &"Variant"
	
	## Return the class of the protocol expected by this port so it can be instantiated.
	static func get_protocol() -> Variant:
		return null
	
	## If the port has no values feeding in, what should it be read as?[br]
	## Override [code]_init()[/code] do define an initial value.
	static func default_value() -> Variant:
		return 0
	static func default_link() -> StringName:
		return &"Link"
	
	func reset():
		value = default_value()
	
	func integrate():
		_integrate()
		aggregate.clear()
	func _integrate():
		if aggregate.size() == 0: return
		value = roundi(aggregate.reduce(func(sum, a):return sum + a, 0) / aggregate.size())
	
	func write_none(data, ..._other):
		return data
	func read_none(data, ..._other):
		return data
	
	## Input data for the next state of the link. It returns an error code, if data isn't accepted.[br]
	## Optionally, a write [code]filter[/code] of a Port class can be chosen, which transforms the format of the data before storing. An error is return if the requested filter doesn't exist.
	func write(val, filter:String="none", filter_args:Array=[]) -> Error:
		if not has_method("write_" + filter):
			return Error.ERR_DOES_NOT_EXIST
		val = callv("write_" + filter, [val] + filter_args)
		aggregate.append(val)
		return Error.OK
	
	## Get current data of the link. Optionally, a read [code]filter[/code] in the Port class may be chosen, which transforms the data that is stored. If the filter doesn't exist, this returns [code]null[/code].
	func read(filter:String="none", filter_args:Array=[]):
		if not has_method("read_" + filter):
			return null
		var val = value
		if value is Object and value.has_method("duplicate"): val = val.duplicate()
		return callv("read_" + filter, [value] + filter_args)


@abstract class NetVert extends Resource:
	## Anything that can be connected in a network, like joints
	## and wires.
	
	@export_group("Porting")
	var port : Port  ## Network Port this Vert is subscribed
	@export var port_class : StringName = "Port"  ## What kind of link is preferred if there's none when connecting this socket? It defines what format, protocol, and variable type the read and write values are.
	@export var accepted_port : Array[StringName] = ["Port"]  ## When connecting to another socket, we assume we can connect to it, but something in our [code]refuse_link[/code] is its [code]link_class[/code] we refuse to connect. Adding it to this array, allows an exception to accept connection.
	@export var refuse_port : Array[StringName]  ## When connecting to another socket, we assume we can connect to it, except if something in our [code]refuse_link[/code] is its [code]link_class[/code], so we refuse to connect. Unless, its [code]link_class[/code] is also in [code]accept_link[/code], so we excpetionally allow connection.
	@export_group("")
	@export_storage var layer : int
	@export var coord : Vector2i : 
		set(val):
			coord = val
			position = Flowchart.from_grid(val)
			emit_changed()
	@export_storage var position : Vector2 :  ## This allows the socket to be found by spatial partitioning.
		set(val):
			position = val
	
	## Returns both grid coordinate and layer as the same data type.
	func get_cell() -> Vector3i:
		return Vector3i(coord.x, coord.y, layer)
	## Sets both grid coordinate and layer from the same data type.
	func set_cell(cell:Vector3i):
		layer = cell.z
		coord = Vector2i(cell.x, cell.y)
	
	func _init() -> void:
		resource_local_to_scene = true
	
	## How to draw this object on the [code]canvas[/code].
	@abstract func draw(chart:Flowchart, canvas:Control, where:Vector2)


	var _link_count : int = 0
	## Get how many NetVert are connected to this one.
	func conns() -> int: return _link_count
	## A connection originated from this node
	func connecter(with:NetVert):
			_link_count += 1
			_connecter(with)
	## A connection destination is this node
	func connectee(with:NetVert):
			_link_count += 1
			_connectee(with)
	func disconnected(from:NetVert):
			_link_count -= 1
			_disconnected(from)
		
	@warning_ignore("unused_parameter")
	## A connection originated from this node
	func _connecter(with:NetVert):
			pass
	@warning_ignore("unused_parameter")
	## A connection destination is this node
	func _connectee(with:NetVert):
			pass
	@warning_ignore("unused_parameter")
	func _disconnected(from:NetVert):
			pass

class Joint extends NetVert:
	func draw(chart:Flowchart, canvas:Control, where:Vector2):
		var color = G.appearance.color.inverted()
		color.a = 0.4
		canvas.draw_circle(where, Flowchart.JOINT_RAD * chart.zoom, color)

class Socket extends Joint:
	signal has_read(val)  ## This socket was used to read a Port. The value is after any Port filtering.
	signal has_written(val)  ## This socket was used to write a Port. The value is after any Port filtering.
	
	enum {
	HIZ,  ## Electrically isolated socket
	SINK,  ## This socket reads a value
	SOURCE,  ## This socket writes a value
	BIDIR  ## This socket can relay a value
	}
	@export_enum("Hi-Z", "Sink", "Source", "Bidir") var mode : int : 
		set(val):
			mode = val
			emit_changed()
	
	func read(filter:="none", ...filter_args) -> Variant:
		var val = port.read(filter, filter_args)
		_has_read(val)
		has_read.emit(val)
		return val
	func write(val, filter:="none", ...filter_args) -> Error:
		val = port.write(val, filter, filter_args)
		_has_written(val)
		has_written.emit(val)
		return val
	
	## This socket was used to read a Port. The value is after any Port filtering.
	@warning_ignore("unused_parameter")
	func _has_read(val):
		pass
	## This socket was used to write a Port. The value is after any Port filtering.
	@warning_ignore("unused_parameter")
	func _has_written(val):
		pass


class Link extends Resource:
	## And object that defines the visual representation of the connection between NetVerts.
	
	@export_storage var pair_hash : int
	@export_storage var chirality : bool  ## "true" means the wire runs clockwise around the corners of an imaginary rectangle.
	@export_storage var bend : float  ## Defines the distance of the diagonal cutting the corner.
	
	static func added_class_info() -> StringName:
		return &"Link"
	
	#region Constructors
	static func from_chi(clockwise:bool) -> Link:
		var wire = Link.new()
		wire.chirality = clockwise
		return wire
	
	static func from_len(start:Vector2, stop:Vector2, longest:bool) -> Link:
		var wire = Link.new()
		wire.set_chi_from_len(start, stop, longest)
		return wire
	#endregion
	
	#region Drawing
	func wire_thick(chart:Flowchart) -> int:
		return clamp(_wire_thick(), 1, Flowchart.MAX_WIRE) * chart.zoom
	static func _wire_thick() -> int:
		return 12
	
	func draw(chart:Flowchart, canvas:Control, start:Vector2, stop:Vector2):
		var color = chart.trace_color_secondary
		if chart.sel_wire.get("wire", null) == self: 
			color = chart.trace_color_primary
		canvas.draw_polyline(get_verts(start, stop), color, wire_thick(chart))
	
	static func draw_chiral(canvas:Control, start:Vector2, stop:Vector2, clockwise:bool, wire_thickness:int, bending:float, color:=Color.WHITE):
		var middle = find_bend_chi(start, stop, clockwise)
		canvas.draw_polyline(get_verts_from(start, middle, stop, bending), color, wire_thickness)
	
	static func draw_length(canvas:Control, start:Vector2, stop:Vector2, longest:bool, wire_thickness:int, bending:float, color:=Color.WHITE):
		var middle = find_bend_len(start, stop, longest)
		canvas.draw_polyline(get_verts_from(start, middle, stop, bending), color, wire_thickness)
	#endregion
	
	## Set handiness of the wire, given whether we want the first segment to be the longest.
	func set_chi_from_len(start:Vector2, stop:Vector2, longest:bool):
		chirality = chi_from_len(start, stop, longest)
	
	## Returns all the vertices to draw this wire, including the diagonal cutting the bend.
	func get_verts(start:Vector2, stop:Vector2) -> PackedVector2Array:
		var middle := find_bend(start, stop)
		return get_verts_from(start, middle, stop, bend)
	
	## Returns the coordinate of the middle vertex from [code]chirality[/code], neglecting [code]bend[/code].
	func find_bend(start:Vector2, stop:Vector2) -> Vector2:
		return find_bend_chi(start, stop, chirality)
	
	## Returns the coordinate of the middle vertex, neglecting [code]bend[/code].
	static func find_bend_chi(start:Vector2, stop:Vector2, clockwise:bool) -> Vector2:
		var diff = (stop - start)
		var diff_sign = diff.sign()
		var which = ((diff_sign.x != diff_sign.y) != clockwise) as int
		return [Vector2(start.x, stop.y), Vector2(stop.x, start.y)][which]
	
	## Returns the coordinate of the middle vertex according to whether the first segment is [code]longest[/code], neglecting [code]bend[/code].
	static func find_bend_len(start:Vector2, stop:Vector2, longest:bool) -> Vector2:
		return find_bend_chi(start, stop, chi_from_len(start, stop, longest))
	
	static func get_verts_from(start:Vector2, middle:Vector2, stop:Vector2, bending:float) -> PackedVector2Array:
		var verts : PackedVector2Array = [start]
		if bending >= 1:
			var segms = [(start - middle), (stop - middle)]
			var shortest = 0 if segms[0].length_squared() < segms[1].length_squared() else 1
			var bend_dist = min(bending, segms[shortest].length())
			segms[0] = segms[0].normalized() * bend_dist + middle
			segms[1] = segms[1].normalized() * bend_dist + middle
			verts.append_array(segms)
		else:
			verts.append(middle)
		verts.append(stop)
		return verts
	
	## Return the chirality of the wire given whether the first segment is the longest.
	static func chi_from_len(start:Vector2, stop:Vector2, longest:bool) -> bool:
		var diff = (stop - start)
		var long = diff.abs().max_axis_index()
		var signs = diff.sign()
		return ((signs.x == signs.y) and (long == 0)) != longest
	
	## Returns a dictionary of data about where the point is on the wire:[br]
	## [code]length[/code] - Total length of the wire.[br]
	## [code]distance[/code] - Travel along the wire until the point in absolute value.[br]
	## [code]ratio[/code] - Travel along the wire as a ratio of the [code]length[/code].[br]
	## [code]subratio[/code] - Travel along found segment, plus count of segments until then.[br]
	## [code]ratio[/code] - Can be between 0 (first corner) and 1 (last corner).[br]
	## The integer part of [code]subratio[/code] tells on which line of the wire the point falls.[br]
	## Returns empty if the point is not over the lines drawn by the wire segment.
	## This includes around the mid corner, if there's a diagonal bend so nothing
	## drawn there.
	func near(point:Vector2, start:Vector2, stop:Vector2) -> Dictionary:
		var verts : PackedVector2Array = get_verts(start, stop)
		var solved : bool  # A segment under the point has been found.
		var total : float = 0.0  # Total wire length.
		var accum : float = 0.0  # Accumulated distance along the path to the point.
		var subratio : float = 0.0  # Distance along path, but as a ratio of each segment.
		for c in range(verts.size() - 1):
			var n = (c + 1) % verts.size()
			var v1 = verts[c]
			var v2 = verts[n]
			var segm = v1 - v2
			var rel = (v1 - point)
			var direct = segm.normalized()
			var normal = Vector2(-direct.y, direct.x)  # Get a perpendicular to `direct`
			var leng = direct.dot(segm)  # Length of segment.
			var dist = direct.dot(rel)  # Distance of point along the segment.
			var along = inverse_lerp(0, leng, dist)  # Distance as a value from 0 to 1.
			var prox = abs(normal.dot(rel))  # Proximity to the segment.
			total += leng
			if solved:
				# Even after finding a matching segment, we keep iterating through
				# all segments so we can find the total length of the wire.
				continue
			if along < 1 and along > 0 and prox < (Flowchart.MAX_WIRE + Flowchart.CLEARANCE):
				# We don't want to accept distances further than a segment's
				# length, which happens when clicking near the mid corner as if
				# bend ratio was 1.
				solved = true
				subratio += along
				accum += dist  # Earlier segment distances + distance along this segment.
			else:
				subratio += 1
				accum += leng  # Account the distance of a rejected segm.
		
		if not solved:
			return {}
		var ratio = inverse_lerp(0, total, accum)
		return {
			"length": total,
			"distance": accum,
			"ratio": ratio,
			"subratio" : subratio,
			}
	
	## Find a coordinate over the wire, at given distance along it.
	func position_along(ratio:float, start:Vector2, stop:Vector2) -> Vector2:
		var verts = [start, find_bend(start,stop), stop]
		var lengs = [(verts[0] - verts[1]).length(), (verts[1] - verts[2]).length()]
		var total = lengs[0] + lengs[1]
		var middle = lengs[0] / total
		var where : Vector2
		if ratio > middle:
			var subratio = inverse_lerp(middle, 1, ratio)
			where = verts[1].lerp(verts[2], subratio)
		else:
			var subratio = inverse_lerp(0, middle, ratio)
			where = verts[0].lerp(verts[1], subratio)
		return where
