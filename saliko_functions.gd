extends RefCounted
class_name Saliko

#TODO Make marching Squares its own thing.

class MarchingSquare:
	var custom_tilemap
	var points : Dictionary[Vector2i, float]  # [coord] = intensity
	var tiles : Dictionary[Vector2i, int]  # [coord] = pattern
	
	func _init(tile_map = null) -> void:
		custom_tilemap = tile_map
	
	func get_tilemap() -> Array:
		return []
	
	## From a space coord, return the point grid coord and its data, if it exists. Otherwise returns [code]default[/code].
	func get_point(coord:Vector2, default=null, cell_size:int=30):
		var point = Vector2i((coord / cell_size).round())
		return [point, points.get(point, default)]
	
	func get_corner_points(tile:Vector2i, cell_size:int=30) -> PackedVector2Array:
		return [
			(Vector2(tile) + Vector2(1, 0)) * cell_size,
			(Vector2(tile) + Vector2(1, 1) * cell_size),
			(Vector2(tile) + Vector2(0, 1)) * cell_size,
			Vector2(tile) * cell_size
		]
	
	func get_adjacent_tiles(point:Vector2i, cell_size:int=30) -> PackedVector2Array:
		return [
			(Vector2(point) + Vector2(0, -1)) * cell_size,
			Vector2(point) * cell_size,
			(Vector2(point) + Vector2(-1, 0)) * cell_size,
			(Vector2(point) + Vector2(-1, -1)) * cell_size,
			]
	
	func set_point(coord:Vector2, val:float = 1.0, cell_size:int=30) -> void:
		var point = get_point(coord, null, cell_size)[0]
		if val == 0:
			points.erase(point)
		else:
			points[point] = val
		
		for each in get_adjacent_tiles(point, cell_size):
			var tile = Vector2i(each)
			tiles[tile] = 0
			var idx : int = -1
			for corner in get_corner_points(each, cell_size):
				idx += 1
				tiles[tile] = tiles.get(tile, 0) | int(points.has(Vector2i(corner))) << idx
				if tiles[tile] == 0:
					tiles.erase(tile)
	
	func get_simple_mesh_outline(cell_size:int=30) -> PackedVector2Array:
		#TODO: Vertex Interpolation
		#TODO: Better way to select which tilemap to use
		var outline : Array[Vector2] = []
		for tile in tiles:
			var pattern = tiles[tile]
			var lines : Array[Vector2] = get_tilemap()[pattern].duplicate()
			
			# Offset coordinates from map into tile
			for idx in range(lines.size()):
				lines[idx] *= cell_size
				lines[idx] += Vector2(tile) * cell_size
			
			outline.append_array(lines)
		return PackedVector2Array(outline)

#region Finding things in Things or about things
## Produce a number sure to not exist in the given set. It will never return 0.
static func get_unique_id(existing:PackedInt32Array = []) -> int:
	var ans = hash(hash(existing) + Time.get_unix_time_from_system() + Time.get_ticks_msec())
	if ans == 0:
		ans = hash(hash([]) + Time.get_unix_time_from_system() + Time.get_ticks_msec())
	return ans

## This is so you can get things in directories relative to a class script's path.[br]
## Supply the instance of the object with the script using [code]from[/code], then the desired path to the folder sibling of that script.
static func relative_path_to(from:Object, to:String) -> String:
	to = to.strip_edges()
	to = to.trim_prefix("./")
	var backtracks : int = 0
	while to.begins_with("../"):  # Find how many folders above to travel.
		backtracks += 1
		to = to.trim_prefix("../")
	
	var path : String = from.get_script().resource_path
	path = path.get_base_dir()  # Remove the script's filename.
	while backtracks > 0:  # Remove parts of the path we backtrack.
		backtracks -= 1
		var split = path.findn("/")
		if split == -1:
			return ""
		path = path.substr(split)
		
	return path.path_join(to)

## Returns information about each defined class, like name and script path. There are options to
## include inner classes found within the classes and if we really just want the inner classes. [br]
## If inner classes include a [code]static func get_base_class() -> String[/code], then the return of that
## static function is also included in the dictionary about it.
static func list_classes(include_inner:bool=false, only_inner:bool=false) -> Array[Dictionary]:
	var all_classes = ProjectSettings.get_global_class_list()
	var all_inners : Array[Dictionary]
	if include_inner:
		for klaso in all_classes:
			var script : Script = load(klaso.path).get_script()
			var karto : Dictionary = script.get_script_constant_map()
			for konst in karto:
				if konst is Script:  # Filter out constant variables.
					all_inners.append({
						"container" : klaso,  # The class of the script defining the inner class
						"base" : "",  # What this inner class extends
						"name" : konst,  # is this the script? What's the name?
						"value" : karto[konst],  # The script or resource of the inner class?
					})
					if karto[konst].has_method("get_base_class"):  #TODO Check if this works
						all_inners.back().base = karto[konst].get_base_class()
	if only_inner:
		return all_inners
	else:
		all_classes.append_array(all_inners)
		return all_classes

## List all the inner classes defined by a particular script. If the inner class
## implements a [code]static func extends_class(class_name:String) -> bool[/code],
## then you may optionally filter for those which return [code]true[/code].[br]
## If the inner class implememnts a [code]static func get_base_class() -> String[/code]
## then the return of that static function is registered in its dictionary.
static func get_inner_classes(container_class:Script, specifically:String="") -> Array[Dictionary]:
	#TODO test if this works.
	var found : Array[Dictionary]
	var karto : Dictionary = container_class.get_script_constant_map()
	for konst in karto:
		if konst is Script:
			var find = {
				"container" : container_class.get_global_name(),
				"base" : "",
				"name" : konst,
				"value" : karto[konst],
				}
			if karto[konst].has_method("get_base_class"):
				find.base = karto[konst].get_base_class()
			if not specifically.is_empty():
				if karto[konst].has_method("extends_class"):
					if karto[konst].extends_class(specifically):
						found.append(find)
			else:
				found.append(find)
	
	return found

## A binary search that's better than [code]Array.bsearch_custom()[/code].[br]
## The [code]callable(find, element)[/code] should return whether [code]find[/code] is lesser than an array element.
static func binary_search(find:float, from:Array, callable:Callable) -> int:  #TODO Test if this works
	var idx : int = floori(from.size()/2.0)
	var dist : int = idx
	while dist > 1:
		var half = floori(idx/2.0)
		dist = idx - half
		if idx >= from.size():
			break
		if callable.call(find, from[idx]):
			idx = half
		else:
			idx += half
	return idx
#endregion

#region Vector Sizzling

class V:
	## A generic Vector class, that can store up to 4 axis and return any
	## combination of them in other Vector formats.
	var x : float
	var y : float
	var z : float
	var w : float
	
	func _init(X:float,Y:float,Z:float=0,W:float=0):
		x = X; y = Y; z = Z; w = W
	## Return float of axle at given index.
	func of1(axle:int) -> float:
		match axle:
			0b00: return x
			0b01: return y
			0b10: return z
			0b11: return w
			_: return NAN
	## Return Vector2 of axis at the indexes given in the bitfield.
	func of2(axis:int) -> Vector2:
		var a : int = axis & 0b11
		var b : int = (axis & 0b1100) >> 2
		return Vector2(of1(a), of1(b))
	## Return Vector3 of axis at the indexes given in the bitfield.
	func of3(axis:int) -> Vector3:
		var a : int = axis & 0b11
		var b : int = (axis & 0b1100) >> 2
		var c : int = (axis & 0b110000) >> 4
		return Vector3(of1(a), of1(b), of1(c))
	## Return Vector4 of axis at the indexes given in the bitfield.
	func of4(axis:int) -> Vector4:
		var a : int = axis & 0b11
		var b : int = (axis & 0b1100) >> 2
		var c : int = (axis & 0b110000) >> 4
		var d : int = (axis & 0b11000000) >> 6
		return Vector4(of1(a), of1(b), of1(c), of1(d))
	## Produce an axis bitfield from the given letters that name each (x,y,z,w).
	func to(axis:String) -> int:
		var n : int = 0
		for s in range(4):
			match axis.substr(s, 1):
				"x": n |= 0b00 << [0,2,4,6][s]
				"y": n |= 0b01 << [0,2,4,6][s]
				"z": n |= 0b10 << [0,2,4,6][s]
				"w": n |= 0b11 << [0,2,4,6][s]
		return n
	## Return axis values given a letter names for axis. The same as using
	## [code]n = to(axis)[/code], then calling the appropriate [code]of*(n)[/code]
	## according to how many letters were given.
	func at(axis:String) -> Variant:
		var n = to(axis)
		match axis.length():
			1: return of1(n)
			2: return of2(n)
			3: return of3(n)
			4: return of4(n)
			_: return NAN

## Taking a Vector2, produce a Vector3, where an optional value is inserted as the missing axis.
static func Vec2AddAxis(vec2:Vector2, axis:int=1, value:float=0) -> Vector3:
	var vec3 := Vector3.ZERO
	var outcome = [[1,2],[0,2],[0,1]][axis]
	vec3[outcome[0]] = vec2[0]
	vec3[outcome[1]] = vec2[1]
	vec3[axis] = value
	return vec3
	
## Taking a Vector3, produce a Vector2, eliminating an axis.
static func Vec3RemAxis(vec3:Vector3, axis:int=1) -> Vector2:
	var vec2 := Vector2.ZERO
	var kept = [[1,2],[0,2],[0,1]][axis]
	vec2[0] = vec3[kept[0]]
	vec2[1] = vec3[kept[1]]
	return vec2
#endregion

#region Fuzzy Comparisons

#FIXME These functions don't take well values that are negative.

static func value_in_reach(point:float, middle:float, span:float) -> bool:
	return abs(point - middle) < span

static func value_between(point:float, start:float, stop:float) -> bool:
		var span = abs(start - stop) / 2
		var middle = span + min(start, stop)
		return value_in_reach(point, middle, span)

static func point_in_reach(point:Vector2, center:Vector2, span:Vector2) -> bool:
	return value_in_reach(point.x, center.x, span.x) and value_in_reach(point.y, center.y, span.y)

## `Rect2.has_point()` could do this, but sometimes you don't want to create a Rect2 from two coordinates.
static func point_in_box(point:Vector2, start:Vector2, stop:Vector2) -> bool:

	return value_between(point.x, start.x, stop.x) and value_between(point.y, start.y, stop.y)
	
#endregion

#region Color Manipulation
## Unlike Color.inverted() this is smarter as it tries to ensure the resulting color is contrasting with the input.
## `margin` constrains the minimum and maximum color value (brightness) allowed.
## If the color has no saturation, like is white or black, `default` give a default hue.
static func negate_color(color:Color, margin:float = 0, default:float = 0) -> Color:
	color.v = clamp(1 - color.v, margin, 1 - margin)  # Bright things become dark, dark things become bright.
	
	if color == Color.BLACK or color == Color.WHITE:
		color.h = default
	color.h = wrapf(color.h + 0.5, 0, 1)  # Rotating halfway around the color wheel.
	return color
#endregion

#region Geometry

## Returns a rectangle as a Vector2 Array, as used in [code]Geometry2D[/code] functions.
static func rect2polygon(rect:Rect2) -> PackedVector2Array:
	return [
		rect.position,
		Vector2(rect.position.x, rect.end.y),
		rect.end,
		Vector2(rect.end.x, rect.position.y),
		]

## Produces the vertices of a prism volume from extruding a polygon as described
## in [code]Geometry2D[/code] functions. Assumes the polygon inscribes the XZ plane[br]
## The [code]position[/code] is the Y offset of the polygon face center, unless
## [code]centroid[/code] is [code]true[/code], in which case it's the center of 
## the [code]length[/code].[br]
## [code]lengh[/code] extrudes towards +Y, but negative value can be given.
static func polygon2prism(polygon:PackedVector2Array, length:float, centroid:=false) -> PackedVector3Array:
	#TODO Test this.
	var prism : PackedVector3Array
	
	var offset : float = 0
	if centroid:
		offset = length / 2
	
	for corner in polygon:
		prism.append(Vec2AddAxis(corner, 1, offset))
		prism.append(Vec2AddAxis(corner, 1, length + offset))
	return prism

## Given the vertices of a geometric solid, shifts their position so it is rotated
## Around the centroid.
static func rotate_volume(verts:PackedVector3Array, angle:float, axis:=Vector3.UP) -> PackedVector3Array:
	var new_volume : PackedVector3Array
	var centroid : Vector3
	var sum := Vector3.ZERO
	for v in verts:
		sum += v
	centroid = sum / verts.size()
	for v in verts:
		new_volume.append((v - centroid).rotated(axis, angle))
	return new_volume

static func perpendicular(a:Vector2, clockwise:=true) -> Vector2:
	if clockwise:
		return Vector2(-a.y, a.x)
	else:
		return Vector2(a.y, -a.x)

## Returns the dot product of a vector against a desired direction and its perpendicular,
## so you can tell if vector [code]a[/code] is left or right of the [code]b[/code] vector.[br]
## In the returned vector, X is 1 if [code]a[/code] is aligned with [code]b[/code],
## -1 if at opposite direction.[br]
## In the returned vector, Y is 1 if [code]a[/code] is at the right side of [code]b[/code],
## -1 if at the left side.
static func alignment(a:Vector2, b:=Vector2.RIGHT) -> Vector2:
	b = b.normalized()
	var perp = perpendicular(b)
	a = a.normalized()
	return Vector2( a.dot(b), a.dot(perp))

## Returns the size of a disc rendered in 2D according to distance of the 3D point
## it represents.
static func apparent_size(cam: Camera3D, true_size:float, distance:float) -> float:
	#FIXME this should be related to FOV, not the near plane.
	return (true_size/(cam.near * 2)) * (1/cam.near/distance)

 
## Returns all coordinates of a grid with the given size. Returns an array of Vector2i if Z is 0.[br]
## Each vector is the start and the end of an axis. End being exclusive, much like in [code]range()[/code].
static func cells_of(x:Vector2i, y:Vector2i, z:=Vector2i.ZERO) -> Array:
	var cells : Array
	var z_range := [z.x]
	if z.y > 0:
		z_range = range(z.x, z.y)
	for zi in z_range:
		for yi in range(y.x, y.y):
			for xi in range(x.x, x.y):
				if z == Vector2i.ZERO:
					cells.append(Vector2i(xi,yi))
				else:
					cells.append(Vector3i(xi,yi,zi))
	return cells

## Given an number of things, return the dimensions of a grid where they are packed the closes like a square.
static func get_square_pack(n:int) -> Vector2i:
	if n == 0:
		return Vector2i.ZERO
	var x : int = ceili(sqrt(n))
	@warning_ignore("integer_division")
	var y : int = ceili(n / x)
	return Vector2i(x,y)

## Given start and end coordinates, find a Rect2 that's valid and positive between them.[br]
## Similar to the [code]Rect2(position, size)[/code] constructor, but you place the end coordinate,
## rather than a rectangle size.
static func get_area(from:Vector2, to:Vector2) -> Rect2:
	var rect = Rect2(from, Vector2.ZERO)
	rect.end = to
	return rect.abs()

#endregion

#region Binary and Bit Manipulation

## Signed Int: Like [code]int(val)[/code], but returns between -1 (false) and 1 (true).
## Optionally you may reverse that logic.
static func sint(val:bool,invert:bool=false):
	#NOTE there aren't bool XOR operators, because [code]a!=b[/code] has the same effect as a "xor(a, b)".
	return 1 if (val!=invert) else -1

## How many digits are in a number?
static func digit_count(num:int, base:int=16) -> int:
	num = abs(num)
	if num == 0 or base < 2:
		return 1
	else:
		return floori(log(num) / log(base) + 1)

## Returns the smallest power of 2 number which can fit the given number.
static func bitwidth(n:int) -> int:
	return digit_count(n, 2)

## Get a mask of all 1 with given amount of bits, in other words the greatest 
## number you can represent with given amount of bits.
static func greatest(width:int) -> int:
	return (1 << width) - 1
	
## Wrapper for [code]greatest()[/code], where it finds how to mask all bits of a given number.
static func filled_bitmask(n:int) -> int:
	var width = bitwidth(n)
	return greatest(width)

## This allows numbering cells in a 2D grid with an unique ID. IDs are always
## positive numbers, even if a coordinate is negative.[br]
## This ID can be decoded back to coordinates using [code]id_vec2i()[/code].[br]
## Each cell axis can't be longer than 30 bit values, so the widest or tallest a
## grid can be is 0x7FFFFFFF units.
static func vec2i_id(coord:Vector2i) -> int:
	var id : int = abs(coord.x) | (abs(coord.y) << 30)
	id |= int(coord.x < 0) << 60
	id |= int(coord.y < 0) << 61
	return id

## Reverses an id from [code]vec2i_id()[/code] back to a grid coordinate.
static func id_vec2i(id:int) -> Vector2i:
	var sign_x = [1,-1][int((id & 0x1000000000000000) > 1)]
	var sign_y = [1,-1][int((id & 0x2000000000000000) > 1)]
	var coord = Vector2i(
		(id & 0x3FFFFFFF) * sign_x,
		((id & 0xFFFFFFFC0000000) >> 30) * sign_y,
		)
	return coord

#endregion

#region DEPRECATED
static func get_grid_cell_id(_cell:Vector2i, _limit:Vector2i, _width:int = 0):
	printerr("Deprecated. Use «vec2i_id()» instead.")
static func get_grid_cell_coord(_id:int, _limit:Vector2i, _width:int = 0):
	printerr("Deprecated - Use «id_vec2i()» instead")
#endregion
