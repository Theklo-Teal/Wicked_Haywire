extends xNetConnect
class_name xWireSegm

const BEND = 0.5

#var rect : Rect2
var corners : Array[CORN]  ## Sequence of corners of the rectangle the wire runs along.
var bend : float = BEND  ## From 0 to 1, how far along the shortest end should a diagonal be done cutting the corner.
var ori_conn : Array[xNetConnect]  ## Other segments connected to the first corner of this one.
var end_conn : Array[xNetConnect]  ## Other segments connected to the last corner of this one.
var ori_position : Vector2  ## The last known absolute position of the origin corner, as a default if there are no connections.
var end_position: Vector2  ## The last known absolute position of the ending corner, as a default if there are no connections.
var color := Color.GOLDENROD
var alt_color := Color.BISQUE

enum VERT {
	ORIGIN,
	MIDDLE,
	ENDING
	}

enum CORN {
	TOPLEFT,
	BOTLEFT,
	TOPRIGHT,
	BOTRIGHT,
	}

const ORIENT = {  ## The orientation of a line connecting the given corners.
	[1,3] : 0,
	[0,2] : 0,
	[0,1] : 1,
	[2,3] : 1,
	}

func get_rect() -> Rect2:
	var ori := ori_position
	var end := end_position
	for each in ori_conn:
		if each is xSocket:
			ori = each.position
			break
	for each in end_conn:
		if each is xSocket:
			end = each.position
			break
	return Rect2(ori, end - ori).abs()

func get_connections() -> Array[xNetConnect]:
	return ori_conn + end_conn

func _init(box:Rect2, ori:CORN, mid:CORN, end:CORN) -> void:
	box = box.abs()
	ori_position = box.position
	end_position = box.end
	corners = [ori, mid, end]

## Get a wire segment knowing the winding direction.
static func from_chiral(start:Vector2, stop:Vector2, clockwise:bool) -> xWireSegm:
	var r = Rect2(start, stop - start)
	var corns = get_corners(r.size, clockwise)
	return xWireSegm.new(r, corns[0], corns[1], corns[2])

## Get a wire segment knowing we want the first line to be either the longest or shortest.
static func from_length(start, stop, short:bool) -> xWireSegm:
	var box = Rect2(start, stop - start)
	var last = last_corner(box.size)
	var chiral = get_chirality(short, last, box.size.abs())
	var corns = get_corners(box.size, chiral)
	return xWireSegm.new(box, corns[0], corns[1], corns[2])

func move_vert(vertex:VERT, where:Vector2):
	if vertex == VERT.ORIGIN:
		ori_position = where
	elif vertex == VERT.ENDING:
		end_position = where

## Returns a dictionary of data about where the point is on the wire:[br]
## [code]length[/code] - Total length of the wire.[br]
## [code]distance[/code] - Travel along the wire until the point in absolute value.[br]
## [code]ratio[/code] - Travel along the wire as a ratio of the [code]length[/code].[br]
## [code]subratio[/code] - Travel along found segment, plus count of segments until then.[br]
## [code]ratio[/code] can be between 0 (first corner) and 1 (last corner).[br]
## The integer part of [code]subratio[/code] tells on which line of the wire the point falls.[br]
## Returns empty if the point is not over the lines drawn by the wire segment.
## This includes around the mid corner, if there's a diagonal bend so nothing
## drawn there.
func near(point:Vector2) -> Dictionary[String, float]:
	## New Method
	var verts = get_verts(true)
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
			accum += leng  # Account rejected segm distance.
	
	if not solved:
		return {}
	return {
		"distance": accum,
		"length": total,
		"ratio": inverse_lerp(0, total, accum),
		"subratio" : subratio,}


## Get the positions of corners this wire segment runs along.
func get_verts(with_bend:=false) -> PackedVector2Array:
	return find_verts(get_rect(), corners[0], corners[1], corners[2], bend if with_bend else -1.0)

## Orientation of a connection.[br]
## Which axis does the line connected to the given end runs along? [br]
## This returns a bitfield where the least significant digit encodes the axis,
## In the same convention as the notation [code]Vector2[axis][/code]:
## 0 -> horizontal, 1 -> vertical. The most second digit is the direction:
## 0 -> negative, 1 -> positive.[br]
## So 0b10 would be +X orientation, 0b01 is -Y, for example.[br]
## This returns -1 if the corner indexes are invalid and can't represent a
## valid wire. This can be used to check if the segment instance represents
## a valid sequence.
@warning_ignore("shadowed_variable")
func conn_orient(last_corner:bool=false) -> int:
	# By summing the selected end corner with the mid corner, we get a unique
	# number to every possible permutation, which then can be used as the index
	# of a lookup table.
	var selected_end = [corners[0], corners[2]][int(last_corner)]
	var segmsum = selected_end + corners[1]
	if selected_end == corners[1] or segmsum in [0,3]:
		# The same corner as mid is selected or 
		# opposite corners selected, which shouldn't be possible.
		return -1
	return [1,0,-1,0,1][segmsum - 1] | int(selected_end > corners[1]) << 1

## Get the winding direction such as the the first line is either longest or shortest.
## box_size must be positive (abs() applied).
static func get_chirality(short_first:bool, end:CORN, box_size:Vector2) -> bool:
	var axis = bool(box_size.min_axis_index()) != short_first
	return [true,false,false,true][end] != axis

## With the size of a Rect2 without abs(), get the order of corners the wire runs along.
static func get_corners(raw_size:Vector2, clockwise:bool) -> Array[CORN]:
	var end = last_corner(raw_size)
	var seq : Array[CORN] = [
		abs(end - 3) as CORN, 
		[[1, 3, 0, 2],[2, 0, 3, 1]][int(clockwise)][end] as CORN,
		end ]
	return seq

static func last_corner(raw_size:Vector2):
	var x = int(raw_size.x > 0)
	var y = int(raw_size.y > 0)
	return ((x << 1) | y ) as CORN

## Returns the length away from the mid corners that bend vertices appear.
## The box must have positive size.
static func find_bend_distance(box:Rect2, ratio:float) -> float:
	var box_size = box.size.snappedf(X.CELL_DIA)
	return min(box_size.x, box_size.y) * ratio

## Finds the vertices to draw a line according to given corners.[br]
## The [code]box[/code] rect must have positive size.[br]
## In agreement with [code]bend[/code], [code]ratio[/code] is a value between
## 0 and 1. If more than 0, it provides vertices to produce a diagonal segment.
## Otherwise, only the vertex at the mid corner is provided.
static func find_verts(box:Rect2, ori:CORN, mid:CORN, end:CORN, ratio:float=-1) -> PackedVector2Array:
	var box_verts = [  # Coordinates of all vertices of the box.
		box.position,
		Vector2(box.position.x, box.end.y),
		Vector2(box.end.x, box.position.y),
		box.end ]
	
	var verts = [
		box_verts[ori],
		box_verts[end] ]
	
	if ratio < 0 or ratio >= 1:
		# Skip finding vertices for a diagonal bend, if ratio is not valid.
		verts.insert(1, box_verts[mid])
		return verts
	
	var bend_dist = find_bend_distance(box, 1 - ratio)
	var bend_x = [  # bend point along the horizontal segment
		Vector2.RIGHT, Vector2.RIGHT, Vector2.LEFT, Vector2.LEFT
		][mid] * bend_dist
	var bend_y = [  # bent point along the vertical segment
		Vector2.DOWN, Vector2.UP, Vector2.DOWN, Vector2.UP
		][mid] * bend_dist
	
	# Finding which of the bend point is appropriate according to
	# orientation of segments from ori and segments from end.
	var ori_segm = [ori, mid]
	ori_segm.sort()
	ori_segm = [bend_x, bend_y][ORIENT[ori_segm]]
	var end_segm = [mid, end]
	end_segm.sort()
	end_segm = [bend_x, bend_y][ORIENT[end_segm]]
	
	verts.insert(1, end_segm + box_verts[mid])
	verts.insert(1, ori_segm + box_verts[mid])

	return verts

## Draws this wire segment on canvas.
func draw(canvas:Control, highlight:bool=false):
	draw_along(canvas, get_rect(), corners[0], corners[1], corners[2], bend, alt_color if highlight else color)

## Given a rectangle with positive size, draw a wire.
static func draw_along(canvas:Control, box:Rect2, ori:CORN, mid:CORN, end:CORN, diagonal:float, clr:=Color.GOLDENROD):
	var verts = find_verts(box, ori, mid, end, diagonal)
	canvas.draw_polyline(verts, clr, X.CELL_RAD * 0.7)

## Given a a rectangle without abs(), draw on canvas according to winding direction.
static func draw_chiral(canvas:Control, box:Rect2, clockwise:bool, diagonal:float, clr:=Color.GOLDENROD):
	var c = get_corners(box.size, int(clockwise))
	draw_along(canvas, box.abs(), c[0], c[1], c[2], diagonal, clr)

## Given a a rectangle without abs(), draw on canvas such as the first line is either the longest or shortest.
static func draw_length(canvas:Control, box:Rect2, long:bool, diagonal:float, clr:=Color.GOLDENROD):
	var end = last_corner(box.size)
	var chiral = get_chirality(long, end, box.size.abs())
	draw_chiral(canvas, box, chiral, diagonal, clr)
