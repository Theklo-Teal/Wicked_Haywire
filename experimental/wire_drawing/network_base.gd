extends RefCounted
class_name xNetBase

## Definition of classes necessary to build a network.

@abstract class xNetNode extends Resource:
	@export_storage var coord : Vector2i
	var colors : Array[Color] = [Color.YELLOW, Color.GOLD, Color.GOLDENROD]
	
	@abstract func draw(canvas:Control, position:Vector2, highlighted:=false)

class xJoint extends xNetNode:
	func draw(canvas:Control, position:Vector2, _highlighted:=false):
		canvas.draw_circle(position, xGraphDraw.CELL_DIA / 2.0, colors[1])

class xVia extends xJoint:
	@export var text : String
	func draw(canvas:Control, position:Vector2, highlighted:=false):
		var color = colors[1] if highlighted else colors[2]
		canvas.draw_circle(position, xGraphDraw.CELL_DIA / 3.0, color, false, 5)

class xWire extends Resource:
	## And object that defines the visual representation of the connection between NetNodes.
	
	enum M {  ## The method used to find the bend corner in the middle of a wire.
		HANDI,  ## Handiness, if clockwise, or counterclockwise of the origin ending.
		LENG,  ## By Length, whether the longest or shortest segment comes from the origin ending. 
		}
	
	@export_storage var mode := M.LENG
	@export_storage var chirality : bool  ## In M.HANDI "true" means clockwise. In M.LENG "true" means longest segment first.
	@export_storage var bend : float  ## Defines the diagonal cutting the corner.

	func draw(canvas:Control, start:Vector2, stop:Vector2, highlighted:=false):
		var color = Color.GOLD if highlighted else Color.GOLDENROD
		canvas.draw_polyline(get_verts(start, stop), color, xGraphDraw.WIRE_THICK)
	
	static func draw_chiral(canvas:Control, start:Vector2, stop:Vector2, clockwise:bool, bending:float):
		var middle = find_bend_chi(start, stop, clockwise)
		canvas.draw_polyline(get_verts_from(start, middle, stop, bending), Color.GOLDENROD, xGraphDraw.WIRE_THICK)
	
	static func draw_length(canvas:Control, start:Vector2, stop:Vector2, longest:bool, bending:float):
		var middle = find_bend_len(start, stop, longest)
		canvas.draw_polyline(get_verts_from(start, middle, stop, bending), Color.GOLDENROD, xGraphDraw.WIRE_THICK)
	
	### Given a a rectangle without [code]abs()[/code], draw on canvas such as the first line is either the longest or shortest.
	#static func draw_length(canvas:Control, box:Rect2, short:bool, clr:=Color.GOLDENROD):
		#var c = get_corners_len(boxGraphDraw.size, short)
		#draw_along(canvas, boxGraphDraw.abs(), c[0], c[1], c[2], 1, clr)
	
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
	
	static func get_verts_from(start:Vector2, middle:Vector2, stop:Vector2, bending:float) -> PackedVector2Array:
		var verts : PackedVector2Array = [start]
		var segms = [(start - middle), (stop - middle)]
		var shortest = 0 if segms[0].length_squared() < segms[1].length_squared() else 1
		var bend_dist = min(bending, segms[shortest].length())
		segms[0] = segms[0].normalized() * bend_dist + middle
		segms[1] = segms[1].normalized() * bend_dist + middle
		verts.append_array(segms)
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
			var subratio = remap(ratio, middle, 1, 0, 1)
			where = verts[1].lerp(verts[2], subratio)
		else:
			var subratio = remap(ratio, 0, middle, 0, 1)
			where = verts[0].lerp(verts[1], subratio)
		return where
