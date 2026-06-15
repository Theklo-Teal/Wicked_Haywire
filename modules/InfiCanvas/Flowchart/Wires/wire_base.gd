extends Resource
class_name FlowchartWire


@export_enum("BEVEL_ORTHO", "BEVEL_DIAGO", "CHICANE_ORTHO", "CHICANE_DIAGO", "SQUARE_CONVEX", "SQUARE_CONCAVE", "ARC_CONVEX", "ARC_CONCAVE") var shape : int
@export var thick : int = 6 : set=_set_thick
@export var color := Color.WHITE

@warning_ignore_start("unused_parameter")
#region Setters and Getters
func _set_thick(val:int):
	if val < 0:
		thick = -1
	else:
		thick = max(1, val)

# Override these functions for more complicated functionality.
func set_thick(val:int, socket:FlowchartSocket=null, graph:FlowchartGraph=null):
	thick = val
func get_thick(socket:FlowchartSocket=null, graph:FlowchartGraph=null) -> int:
	return thick

func set_color(val:Color, socket:FlowchartSocket=null, graph:FlowchartGraph=null):
	color = val
func get_color(socket:FlowchartSocket=null, graph:FlowchartGraph=null) -> Color:
	return color
#endregion

#region Responding to Simulation state
## [code]socket[/code] is the socket hosting this wire.
func cycle_begin(socket:FlowchartSocket):
	pass
## [code]socket[/code] is the socket hosting this wire.[br]
## I hope nobody needs to write to Links using Wires.
func update(graph:FlowchartGraph, socket:FlowchartSocket):
	pass
## [code]socket[/code] is the socket hosting this wire.
func cycle_finish(socket:FlowchartSocket):
	pass
#endregion
@warning_ignore_restore("unused_parameter")

# Wire Shapes
enum {
	ORTHO = 0b0,
	DIAGO = 0b1,
	CONVEX = 0b0,
	CONCAVE = 0b1,
	
	BEVEL = 0b000,
	CHICANE = 0b010,
	SQUARE = 0b100,
	ARC = 0b110,
	
	BEVEL_ORTHO = 0b000,
	BEVEL_DIAGO = 0b001,
	CHICANE_ORTHO = 0b10,
	CHICANE_DIAGO = 0b011,
	SQUARE_CONVEX = 0b100,
	SQUARE_CONCAVE = 0b101,
	ARC_CONVEX = 0b110,
	ARC_CONCAVE = 0b111,
	}

#region Wire Functions

func get_vertices(start:Vector2, stop:Vector2, offset:=Vector2.ZERO) -> PackedVector2Array:
	var box = stop - start
	var info = {
			"start" : Vector2i(start),
			"stop" : Vector2i(stop),
			"box": Vector2i(box),
			"sign": Vector2i(box.sign()),
			"singular": start == stop,
			"ortho_has_bends": not (box.x == 0 or box.y == 0 or start == stop),  # Is the line from start to stop horizontal or vertical?
			"diago_has_bends": not (box.x == box.y or start == stop),  # Is the line from start to stop a 45 degree diagonal?
		}
	if info.singular:
		return []
	
	var vertices : PackedVector2Array
	match shape:
		BEVEL_ORTHO:
			vertices = get_orthogonal_wire(start, stop, info)
		BEVEL_DIAGO:
			vertices = get_diagonal_wire(start, stop, info)
		CHICANE_ORTHO:
			vertices = get_orthogonal_chicane_wire(start, stop, info)
		CHICANE_DIAGO:
			vertices = get_diagonal_chicane_wire(start, stop, info)
		SQUARE_CONVEX:
			vertices = get_convex_square_wire(start, stop, info)
		SQUARE_CONCAVE:
			vertices = get_concave_square_wire(start, stop, info)
		ARC_CONVEX:
			pass
		ARC_CONCAVE:
			pass
		_:
			vertices = PackedVector2Array( [start, stop] )
	
	for v in range(vertices.size()):
		vertices[v] += offset
	
	return vertices

## The vertices of a wire which starts with a line orthogonal to the grid, then ends in diagonal.
func get_orthogonal_wire(start, stop, info) -> PackedVector2Array:
	if info.singular:
		return PackedVector2Array([])
	if not (info.ortho_has_bends or info.diago_has_bends):
		return PackedVector2Array([info.start, info.stop])
	
	var box_abs : Vector2i = info.box.abs()
	var axis = box_abs.max_axis_index()
	var sixa = box_abs.min_axis_index()
	
	var ortho := Vector2i.ZERO
	ortho[axis] = (box_abs[axis] - box_abs[sixa]) * info.sign[axis]
	
	return PackedVector2Array([
			info.start,
			info.start + ortho,
			info.stop,
		])

## The vertices of a wire which starts with a line diagonal to the grid, then ends in orthogonal.
func get_diagonal_wire(start, stop, info) -> PackedVector2Array:
	if info.singular:
		return PackedVector2Array([])
	if not (info.ortho_has_bends or info.diago_has_bends):
		return PackedVector2Array([info.start, info.stop])
	
	var box_abs : Vector2i = info.box.abs()
	var axis = box_abs.max_axis_index()
	var sixa = box_abs.min_axis_index()
	
	var ortho := Vector2i.ZERO
	ortho[axis] = (box_abs[axis] - box_abs[sixa]) * info.sign[axis]
	
	return PackedVector2Array([
			info.start,
			info.stop - ortho,
			info.stop,
		])

## The vertices of a wire that starts and ends on lines orthogonal to the grid.
func get_orthogonal_chicane_wire(start:Vector2, stop:Vector2, info) -> PackedVector2Array:
	if info.singular:
		return PackedVector2Array([])
	if not (info.ortho_has_bends or info.diago_has_bends):
		return PackedVector2Array([info.start, info.stop])
	
	var box_abs : Vector2i = info.box.abs()
	var axis = box_abs.max_axis_index()
	var sixa = box_abs.min_axis_index()
	
	var ortho := Vector2i.ZERO
	ortho[axis] = (box_abs[axis] - box_abs[sixa]) / 2.0 * info.sign[axis]
	
	return PackedVector2Array([
			info.start,
			info.start + ortho,
			info.stop - ortho,
			info.stop,
		])

## The vertices of a wire that starts and ends on lines diagonal to the grid.
func get_diagonal_chicane_wire(start:Vector2, stop:Vector2, info) -> PackedVector2Array:
	if info.singular:
		return PackedVector2Array([])
	if not (info.ortho_has_bends or info.diago_has_bends):
		return PackedVector2Array([info.start, info.stop])
	
	var box_abs : Vector2i = info.box.abs()
	var sixa = box_abs.min_axis_index()
	
	var diago : Vector2i = info.sign
	diago *= box_abs[sixa] / 2.0
	
	return PackedVector2Array([
			info.start,
			info.start + diago,
			info.stop - diago,
			info.stop,
		])

## Draws with a 90 degree corner, where the longest segment is first.
func get_convex_square_wire(start:Vector2, stop:Vector2, info) -> PackedVector2Array:
	if info.singular:
		return PackedVector2Array([])
	if not info.ortho_has_bends:
		return PackedVector2Array([info.start, info.stop])
	
	var box_abs : Vector2i = info.box.abs()
	var sixa = box_abs.min_axis_index()
	
	var ans := Vector2.ZERO
	ans.x = [start.x, stop.x][sixa]
	ans.y = [stop.y, start.y][sixa]
	
	return PackedVector2Array([
		info.start,
		ans,
		info.stop,
	])

## Draws with a 90 degree corner, where the short segment is first.
func get_concave_square_wire(start:Vector2, stop:Vector2, info) -> PackedVector2Array:
	if info.singular:
		return PackedVector2Array([])
	if not info.ortho_has_bends:
		return PackedVector2Array([info.start, info.stop])
	
	var box_abs : Vector2i = info.box.abs()
	var axis = box_abs.max_axis_index()
	
	var ans := Vector2.ZERO
	ans.x = [start.x, stop.x][axis]
	ans.y = [stop.y, start.y][axis]
	
	return PackedVector2Array([
		info.start,
		ans,
		info.stop,
	])
#endregion
