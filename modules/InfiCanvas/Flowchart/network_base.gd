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
	@export_storage var coord : Vector2i :
		set(val):
			coord = val
			position = G.from_grid(coord)
	@export_storage var position : Vector2  #NOTE: Spatial position is not to be relied on authoritavely. It should be updated whenever [code]coord[/code] is set, functioning as a cache so we don't have to call grid snapping all the time.
	@export_storage var layer : int
	
	## Returns both grid coordinate and layer as the same data type.
	func get_cell() -> Vector3i:
		return Vector3i(coord.x, coord.y, layer)
	## Sets both grid coordinate and layer from the same data type.
	func set_cell(cell:Vector3i):
		layer = cell.z
		coord = Vector2i(cell.x, cell.y)
	
	## How to draw this object on the [code]canvas[/code].
	@abstract func draw(canvas:Control)


class Joint extends NetVert:
	func draw(canvas:Control):
		draw_at(canvas, position)
	
	static func draw_at(canvas:Control, where:Vector2):
		var color = G.appearance.color.inverted()
		color.a = 0.4
		canvas.draw_circle(where, G.joint_rad, color)

class Via extends Joint:
	## A simple Joint that isn't associated with Gizmos and to be used
	## as the ending of a wire and labelled to create a tunnel connection.
	
	@export var text : String = ""
	
	func draw(canvas:Control):
		#if connected.size() != 2 or not text.is_empty():
		var thick = G.joint_rad - G.via_hole # Find the thickness that produces a hole of constant size.
		canvas.draw_circle(G.chart.to_screen_coord(position),
			G.joint_rad - thick / 2.0 - G.clearance,
			G.appearance.trace_primary,
			false, thick)

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
	func has_read(val):
		pass
	## This socket was used to write a Port.
	func has_written(val):
		pass


class Link extends Resource:
	## And object that defines the visual representation of the connection between NetVerts.
	enum M {  ## The method used to find the bend corner in the middle of a wire.
		HANDI,  ## Handiness, if clockwise, or counterclockwise of the origin ending.
		LENG,  ## By Length, whether the longest or shortest segment comes from the origin ending. 
		}
	@export_storage var mode := M.LENG
	@export_storage var chirality : bool  ## In M.HANDI "true" means clockwise. In M.LENG "true" means longest segment first.
	@export_storage var bend : float :  ## Number from 0 to 1 as ratio, where 1 is the length of of shortest segment. It defines the diagonal segment of a corner.
		set(val):
			bend = clamp(val, 0, 1)
	
	func draw(canvas:Control, start:Vector2, stop:Vector2):
		canvas.draw_polyline(get_verts(start, stop), G.appearance.trace_primary, G.max_wire)
	
	static func draw_chiral(canvas:Control, start:Vector2, stop:Vector2, clockwise:bool, bend_dist:float):
		var middle = find_bend_chi(start, stop, clockwise)
		canvas.draw_polyline(get_verts_from(start, middle, stop, bend_dist), G.appearance.trace_primary, G.max_wire)
	
	static func draw_length(canvas:Control, start:Vector2, stop:Vector2, longest:bool, bend_dist:float):
		var middle = find_bend_len(start, stop, longest)
		canvas.draw_polyline(get_verts_from(start, middle, stop, bend_dist), G.appearance.trace_primary, G.max_wire)
	
	## Returns the coordinate of the middle vertex, neglecting [code]bend[/code].
	func find_bend(start:Vector2, stop:Vector2) -> Vector2:
		match mode:
			M.HANDI:
				return find_bend_chi(start, stop, chirality)
			M.LENG:
				return find_bend_len(start, stop, chirality)
		return start.lerp(stop, 0.5)
	
	## Returns all the vertices to draw this wire, including the diagonal cutting the bend.
	func get_verts(start:Vector2, stop:Vector2) -> PackedVector2Array:
		var middle := find_bend(start, stop)
		return get_verts_from(start, middle, stop, bend)
	
	static func find_bend_chi(start:Vector2, stop:Vector2, clockwise:bool) -> Vector2:
		var diff = (stop - start)
		var diff_sign = diff.sign()
		var which = ((diff_sign.x != diff_sign.y) != clockwise) as int
		return [Vector2(start.x, stop.y), Vector2(stop.x, start.y)][which]
	
	static func find_bend_len(start:Vector2, stop:Vector2, longest:bool) -> Vector2:
		var diff = (stop - start)
		var diff_abs = diff.abs()
		var axis = diff_abs.max_axis_index() if longest else diff_abs.min_axis_index()
		return [Vector2(start.x, stop.y), Vector2(stop.x, start.y)][axis]
	
	static func get_verts_from(start:Vector2, middle:Vector2, stop:Vector2, bend_dist:float) -> PackedVector2Array:
		var verts : PackedVector2Array = [start]
		var box = (start - stop).abs()
		var short_axis : int = box.min_axis_index()  # Figure out the maximum bend_dist.
		var segms = [(start - middle), (stop - middle)]
		var segm_norm = [segms[0].normalized(), segms[1].normalized()]
		bend_dist = clampf(bend_dist, G.snap, box[short_axis])
		verts.append(segm_norm[0] * bend_dist + middle)
		verts.append(segm_norm[1] * bend_dist + middle)
		verts.append(stop)
		return verts
	
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
	func near(point:Vector2, verts:PackedVector2Array) -> Dictionary:
		var solved : bool  # A segment under the point has been found.
		var total : float = 0.0  # Total wire length.
		var accum : float = 0.0  # Accumulated distance along the path to the point.
		var subratio : float = 0.0  # Distance along path, but as a ratio of each segment.
		for c in range(verts.size()):
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
			if along < 1 and along > 0 and prox < G.snap / 2.0:
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
