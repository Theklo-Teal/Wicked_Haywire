@abstract
extends Node
class_name NetBase

## Definition of classes necessary to build a network.

#region Simulation Override Functions
signal update_done
signal begin_done
signal finish_done

@warning_ignore_start("unused_parameter")
func update(graph:FlowchartNetwork):
	_update(graph)
	update_done.emit()

func cycle_begin():
	_cycle_begin()
	begin_done.emit()

func cycle_finish():
	_cycle_finish()
	finish_done.emit()

func _update(graph:FlowchartNetwork):
	pass

func _cycle_begin():
	pass

func _cycle_finish():
	pass
@warning_ignore_restore("unused_parameter")
#endregion

class Port:
	## Target for signals being conveyed during simulation using an Observer Pattern.
	
	var value
	var aggregate : Array
	
	## If the port has no values feeding in, what should it be read as?
	static func default():
		return 0
	func integrate():
		value = roundi(aggregate.reduce(func(sum, a):return sum + a, 0) / aggregate.size())
	func read():
		return value
	func write(val):
		aggregate.append(val)


@abstract class NetVert extends Resource:
	## Anything that can be connected in a network, like joints
	## and wires.
	
	@export_storage var layer : int
	@export_storage var coord : Vector2i : 
		set(val):
			coord = val
			position = Flowchart.from_grid(val)
	@export_storage var position : Vector2  ## This allows the socket to be found by spatial partitioning.
	
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
	@abstract func draw(canvas:Control, where:Vector2)


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
	func draw(canvas:Control, where:Vector2):
		var color = G.appearance.color.inverted()
		color.a = 0.4
		canvas.draw_circle(where, Flowchart.JOINT_RAD, color)

class Socket extends Joint:
	enum {
	HIZ,  ## Electrically isolated socket
	SINK,  ## This socket reads a value
	SOURCE,  ## This socket writes a value
	BIDIR  ## This socket can relay a value
	}
	@export_enum("Hi-Z", "Sink", "Source", "Bidir") var mode : int
	@export_group("Porting")
	@export var port_class : StringName = "Port"  ## What kind of link is preferred if there's none when connecting this socket? It defines what format, protocol, and variable type the read and write values are.
	@export var accepted_port : Array[StringName] = ["Port"]  ## When connecting to another socket, we assume we can connect to it, but something in our [code]refuse_link[/code] is its [code]link_class[/code] we refuse to connect. Adding it to this array, allows an exception to accept connection.
	@export var refuse_port : Array[StringName]  ## When connecting to another socket, we assume we can connect to it, except if something in our [code]refuse_link[/code] is its [code]link_class[/code], so we refuse to connect. Unless, its [code]link_class[/code] is also in [code]accept_link[/code], so we excpetionally allow connection.

	## This socket was used to read a Port.
	@warning_ignore("unused_parameter")
	func has_read(val):
		pass
	## This socket was used to write a Port.
	@warning_ignore("unused_parameter")
	func has_written(val):
		pass


class Link extends Resource:
	## And object that defines the visual representation of the connection between NetVerts.

	@export_storage var chirality : bool  ## "true" means the wire runs clockwise around the corners of an imaginary rectangle.
	@export_storage var bend : float  ## Defines the distance of the diagonal cutting the corner.
	
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
	func draw(canvas:Control, start:Vector2, stop:Vector2, highlighted:=false):
		var color = Color.GOLD if highlighted else Color.GOLDENROD
		canvas.draw_polyline(get_verts(start, stop), color, Flowchart.MAX_WIRE)
	
	static func draw_chiral(canvas:Control, start:Vector2, stop:Vector2, clockwise:bool, bending:float):
		var middle = find_bend_chi(start, stop, clockwise)
		canvas.draw_polyline(get_verts_from(start, middle, stop, bending), Color.GOLDENROD, Flowchart.MAX_WIRE)
	
	static func draw_length(canvas:Control, start:Vector2, stop:Vector2, longest:bool, bending:float):
		var middle = find_bend_len(start, stop, longest)
		canvas.draw_polyline(get_verts_from(start, middle, stop, bending), Color.GOLDENROD, Flowchart.MAX_WIRE)
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
			var normal = Saliko.perpendicular(direct)
			var leng = direct.dot(segm)  # Length of segment.
			var dist = direct.dot(rel)  # Distance of point along the segment.
			var along = inverse_lerp(0, leng, dist)  # Distance as a value from 0 to 1.
			var prox = abs(normal.dot(rel))  # Proximity to the segment.
			total += leng
			if solved:
				# Even after finding a matching segment, we keep iterating through
				# all segments so we can find the total length of the wire.
				continue
			if along < 1 and along > 0 and prox < Flowchart.SNAP / 2.0:
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
