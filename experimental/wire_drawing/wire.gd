extends Resource
class_name xWire

## And object defining the connection between two xJoint and how to draw it visually.

enum VERT { ORIGIN, MIDDLE, ENDING }
enum CORN { NULL = -1, TOPLEFT, BOTLEFT, TOPRIGHT, BOTRIGHT }

@export_storage var ori_conn : xJoint
@export_storage var end_conn : xJoint
@export_storage var corners : Array[CORN]  ## Sequence of corners of the rectangle the wire runs along.
@export_storage var bend : float = 1  ## From 0 to 1, how far along the shortest end should a diagonal be done cutting the corner.

var color := Color.GOLDENROD
var alt_color := Color.GOLD

#region Instance Information

## Returns whether two xJoint are connected by this wire.[br]
## Optionally it can be strict about the direction of connection and whether
## That direction is backwards.
func connects(start:xJoint, stop:xJoint, directional:=false, reversed:=false) -> bool:
	var truth = [
		ori_conn == start,
		end_conn == stop,
		ori_conn == stop,
		end_conn == start
		]
	if directional:
		return truth[2 if reversed else 0] and truth[3 if reversed else 1]
	else:
		return truth[0] != truth[2] and truth[1] != truth[3]

func get_rect() -> Rect2:
	return Rect2(ori_conn.position, end_conn.position - ori_conn.position).abs()

## Returns which line coming from an end is either the longest or the shortest.
func get_leg(longest:bool) -> VERT:
	if corners[VERT.MIDDLE] == CORN.NULL:
		return VERT.ORIGIN
	else:
		var verts = get_verts(false)
		var ori = (verts[0] - verts[1]).length()
		var end = (verts[-2] - verts[-1]).length()
		return VERT.ORIGIN if (ori < end != longest) else VERT.ENDING

## Returns a vector of the either the shortest or longest part. The direction
## follows the [code]corners[/code] sequence.
func get_edge(longest:bool) -> Vector2:
	#TODO Test this.
	var verts = get_verts()
	var ori = verts[1] - verts[0]
	var end = verts[2] - verts[1]
	var ori_axis = is_vertical(corners[0], corners[1]) as int
	var end_axis = is_vertical(corners[1], corners[2]) as int
	return [ori, end][int(abs(ori[ori_axis]) < abs(end[end_axis]) != longest)]

## Get the positions of corners this wire segment runs along.
func get_verts(with_bend:=false) -> PackedVector2Array:
	return find_verts(get_rect(), corners[0], corners[1], corners[2], bend if with_bend else -1.0)

## Returns a dictionary of data about where the point is on the wire:[br]
## [code]length[/code] - Total length of the wire.[br]
## [code]distance[/code] - Travel along the wire until the point in absolute value.[br]
## [code]ratio[/code] - Travel along the wire as a ratio of the [code]length[/code].[br]
## [code]subratio[/code] - Travel along found segment, plus count of segments until then.[br]
## [code]ratio[/code] - Can be between 0 (first corner) and 1 (last corner).[br]
## [code]joint[/code] - the [code]xJoint[/code] connected to the end closest to the point.[br]
## [code]rect[/code] - the rectangle of the wire at the moment of the call.[br]
## The integer part of [code]subratio[/code] tells on which line of the wire the point falls.[br]
## Returns empty if the point is not over the lines drawn by the wire segment.
## This includes around the mid corner, if there's a diagonal bend so nothing
## drawn there.
func near(point:Vector2) -> Dictionary:
	var rect = get_rect()
	var verts = find_verts(rect, corners[0], corners[1], corners[2], bend)
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
			# Even after finding a matching segment,we keep iterating through
			# all segments so we can find the total length of the wire.
			continue
		if along < 1 and along > 0 and prox < X.CELL_DIA / 2.0:
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
	var joint : xJoint = [ori_conn, end_conn][int(ratio < 0.5)]
	return {
		"distance": accum,
		"length": total,
		"ratio": ratio,
		"subratio" : subratio,
		"joint": joint,
		"rect": rect, 
		}

## Finds the vertex of a point along the wire segment.[br]
## Use [code]near().subratio/code] to find the [code]where[/code].
func find_point(subratio:float) -> Vector2:
	var rect = get_rect()
	var verts = all_verts(rect)
	var dist = subratio - floor(subratio)
	var first = corners[floori(subratio)]
	var last = corners[VERT.ENDING] if corners[VERT.MIDDLE] == CORN.NULL else corners[VERT.MIDDLE]
	var axis = is_vertical(first, last)
	var dist_len = inverse_lerp(verts[first][axis as int], verts[last][axis as int], dist)
	if axis:
		return Vector2(verts[first][not axis as int], dist_len)
	else:
		return Vector2(dist_len, verts[first][not axis as int])
#endregion

#region Constructors
func _init(start:xJoint, stop:xJoint, ori:CORN, mid:CORN, end:CORN) -> void:
	ori_conn = start
	end_conn = stop
	var minimum = min(ori_conn.x - end_conn.x, ori_conn.y - end_conn.y)
	var min_size = X.CELL_RAD - X.CLEARANCE
	if minimum <= min_size:
		mid = CORN.NULL
	
	corners = [ori, mid, end]

## Get a wire segment knowing the winding direction.
static func from_chiral(start:xJoint, stop:xJoint, clockwise:bool) -> xWire:
	var vec = Vector2(stop.position - start.position)
	var corns = get_corners_chi(vec, clockwise)
	return xWire.new(start, stop, corns[0], corns[1], corns[2])

## Get a wire segment knowing we want the first line to be either the longest or shortest.
static func from_length(start:xJoint, stop:xJoint, short:bool) -> xWire:
	var vec = Vector2(stop.position - start.position)
	var corns = get_corners_len(vec, short)
	return xWire.new(start, stop, corns[0], corns[1], corns[2])

#endregion

#region Calculations
## Get the absolute position of all vertices of the given rectangle.
## [code]box[/code] must have positive size.[br]
## The index of the array matches [code]CORN[/code] definition.
static func all_verts(box:Rect2) -> PackedVector2Array:
	return [ box.position, Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y), box.end ]

## For a line between [code]start[/code] and [code]stop[/code],[br]
## return whether the line is vertical. It is useful in combination with
## [code]Vector2.min_axis_index()[/code] or [code]Vector2.max_axis_index()[/code].
static func is_vertical(start:CORN, stop:CORN) -> bool:
	var sum = start + stop
	return sum & 0b1
## For a vector between [code]start[/code] and [code]stop[/code],[br]
## return whether the axle given by [code]is_vertical()[/code] is positive. It is useful in combination with
static func is_positive(start:CORN, stop:CORN) -> bool:
	return start > stop

## Get the winding direction such as the the first line is either longest or shortest.
## [code]box_size[/code] must be positive ([code]abs()[/code] applied).
static func get_chirality(short_first:bool, end:CORN, box_size:Vector2) -> bool:
	var axis = bool(box_size.min_axis_index()) != short_first
	return [true,false,false,true][end] != axis

## With the size of a Rect2 without [code]abs()[/code], get the order of corners the wire runs along.[br]
## Uses length-first, whether is the shortest, to decide middle corner position.
static func get_corners_len(raw_size:Vector2, shortest:bool) -> Array[CORN]:
	var x = int(raw_size.x > 0)
	var y = int(raw_size.y > 0)
	var end = ((x << 1) | y ) as CORN
	var chi = get_chirality(shortest, end, raw_size.abs())
	return get_corners_chi(raw_size, chi)

## With the size of a Rect2 without [code]abs()[/code], get the order of corners the wire runs along.[br]
## Uses chirality to decide middle corner position.
static func get_corners_chi(raw_size:Vector2, clockwise:bool) -> Array[CORN]:
	var x = int(raw_size.x > 0)
	var y = int(raw_size.y > 0)
	var end = ((x << 1) | y ) as CORN
	var seq : Array[CORN] = [
		abs(end - 3) as CORN, 
		end ]
	
	raw_size = raw_size.abs()
	var min_size = X.CELL_RAD - X.CLEARANCE
	if min(raw_size.x, raw_size.y) > min_size:
		seq.insert(1, [[1, 3, 0, 2],[2, 0, 3, 1]][int(clockwise)][end] as CORN )
	else:
		seq.insert(1, CORN.NULL)
	return seq

## Returns the length away from the mid corners that bend vertices appear.[br]
## Set [code]invert[/code] if you want distance from the middle point instead.
## The [code]box_size[/code] must be positive ([code]abs()[/code] applied).
static func find_bend_distance(box_size:Vector2, ratio:float, invert:bool) -> float:
	var dist = min(box_size.x, box_size.y)
	return max(dist * (1 - ratio), X.CELL_RAD) if invert else min(dist * ratio, dist - X.CELL_RAD)

## Finds the vertices to draw a line according to given corners.[br]
## The [code]box[/code] rect must have positive size.[br]
## In agreement with [code]bend[/code], [code]ratio[/code] is a value between
## 0 and 1. If more than 0, it provides vertices to produce a diagonal segment.
## Otherwise, only the vertex at the mid corner is provided.
static func find_verts(box:Rect2, ori:CORN, mid:CORN, end:CORN, ratio:float=-1) -> PackedVector2Array:
	var box_verts = all_verts(box)
	var verts = [
		box_verts[ori],
		box_verts[end] ]
	
	if mid == CORN.NULL:
		# Skip finding the bend corner, if there's no mid point
		return verts
	
	if abs(ratio - 0.5) > 0.5:
		# Skip finding vertices for a diagonal bend, if ratio is not valid.
		verts.insert(1, box_verts[mid])
		return verts
	
	var bend_dist = find_bend_distance(box.size, ratio, true)
	var bend_x = [  # bend point along the horizontal segment
		Vector2.RIGHT, Vector2.RIGHT, Vector2.LEFT, Vector2.LEFT
		][mid] * bend_dist
	var bend_y = [  # bent point along the vertical segment
		Vector2.DOWN, Vector2.UP, Vector2.DOWN, Vector2.UP
		][mid] * bend_dist
	
	# Finding which of the bend point is appropriate according to
	# orientation of segments from ori and segments from end.
	var ori_segm : Vector2 = [bend_x, bend_y][is_vertical(ori, mid) as int]
	var end_segm : Vector2 = [bend_x, bend_y][is_vertical(mid, end) as int]
	ori_segm += box_verts[mid]
	end_segm += box_verts[mid]
	
	verts.insert(1, end_segm)
	verts.insert(1, ori_segm)

	return verts
#endregion

#region Draw Methods
## Draws this wire segment on canvas.
func draw(canvas:Control, highlight:bool=false):
	draw_along(canvas, get_rect(), corners[0], corners[1], corners[2], bend, alt_color if highlight else color)

## Given a rectangle with positive size, draw a wire.
static func draw_along(canvas:Control, box:Rect2, ori:CORN, mid:CORN, end:CORN, ratio:float=1, clr:=Color.GOLDENROD):
	var verts = find_verts(box, ori, mid, end, ratio)
	canvas.draw_polyline(verts, clr, X.CELL_RAD * 0.5)

## Given a a rectangle without [code]abs()[/code], draw on canvas according to winding direction.
static func draw_chiral(canvas:Control, box:Rect2, clockwise:bool, clr:=Color.GOLDENROD):
	var c = get_corners_chi(box.size, int(clockwise))
	draw_along(canvas, box.abs(), c[0], c[1], c[2], 1, clr)

## Given a a rectangle without [code]abs()[/code], draw on canvas such as the first line is either the longest or shortest.
static func draw_length(canvas:Control, box:Rect2, short:bool, clr:=Color.GOLDENROD):
	var c = get_corners_len(box.size, short)
	draw_along(canvas, box.abs(), c[0], c[1], c[2], 1, clr)
#endregion
