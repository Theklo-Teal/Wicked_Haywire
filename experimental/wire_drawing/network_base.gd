extends RefCounted
class_name xNetBase

## Definition of classes necessary to build a network.

@abstract class xNetVert extends Resource:
	## Base class for a graph vertex in a network
	
	@export_storage var coord : Vector2i
	
	var colors : Array[Color] = [Color.YELLOW, Color.GOLD, Color.GOLDENROD]
	@abstract func draw(canvas:Control, position:Vector2, highlighted:=false)
	
	var _link_count : int = 0
	func size() -> int: return _link_count
	## A connection originated from this node
	func connecter(with:xNetVert):
		_link_count += 1
		_connecter(with)
	## A connection destination is this node
	func connectee(with:xNetVert):
		_link_count += 1
		_connectee(with)
	func disconnected(from:xNetVert):
		_link_count -= 1
		_disconnected(from)
	
	@warning_ignore("unused_parameter")
	## A connection originated from this node
	func _connecter(with:xNetVert):
		pass
	@warning_ignore("unused_parameter")
	## A connection destination is this node
	func _connectee(with:xNetVert):
		pass
	@warning_ignore("unused_parameter")
	func _disconnected(from:xNetVert):
		pass


class xWire extends Resource:
	## And object that defines the visual representation of the connection between NetNodes.
	
	@export_storage var chirality : bool  ## "true" means the wire runs clockwise around the corners of an imaginary rectangle.
	@export_storage var bend : float  ## Defines the diagonal cutting the corner.
	
	#region Constructors
	static func from_chi(clockwise:bool) -> xWire:
		var wire = xWire.new()
		wire.chirality = clockwise
		return wire
	
	static func from_len(start:Vector2, stop:Vector2, longest:bool) -> xWire:
		var wire = xWire.new()
		wire.set_chi_from_len(start, stop, longest)
		return wire
	#endregion
	
	#region Drawing
	func draw(canvas:Control, start:Vector2, stop:Vector2, highlighted:=false):
		var color = Color.GOLD if highlighted else Color.GOLDENROD
		canvas.draw_polyline(get_verts(start, stop), color, xGraphDraw.WIRE_THICK)
	
	static func draw_chiral(canvas:Control, start:Vector2, stop:Vector2, clockwise:bool, bending:float):
		var middle = find_bend_chi(start, stop, clockwise)
		canvas.draw_polyline(get_verts_from(start, middle, stop, bending), Color.GOLDENROD, xGraphDraw.WIRE_THICK)
	
	static func draw_length(canvas:Control, start:Vector2, stop:Vector2, longest:bool, bending:float):
		var middle = find_bend_len(start, stop, longest)
		canvas.draw_polyline(get_verts_from(start, middle, stop, bending), Color.GOLDENROD, xGraphDraw.WIRE_THICK)
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
	func near(point:Vector2, verts:PackedVector2Array) -> Dictionary:
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
			if along < 1 and along > 0 and prox < xGraphDraw.CELL_DIA / 2.0:
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
