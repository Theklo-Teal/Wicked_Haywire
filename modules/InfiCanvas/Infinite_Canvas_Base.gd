@tool
extends ColorRect

## This script defines the basic function of InfiCanvas, without bothering with
## input handling or states.

const DEBUGGING = false
const MINIMUM_LASSO = Vector2(16,16)  # A lasso operation is only performed if its rect size is larger than this. Otherwise, a click was probably intended.
const SCROLL_SPEED = Vector2(20, 20)
const ZOOM_SPEED = 0.2

@export var parti : Dictionary[Variant, SpatialPartition] :  ## Partition spaces available, indexed by a String or an Enum.
	set(val):
		parti = val
		if not parti.has(0):
			parti[0 as Variant] = SpatialPartition.new()

var all_objs : Dictionary[Variant, SpatialPartition]  # Track which partitions objects are in.

@export_group("Appearance")
@export_range(1, 200, 1, "or_greater") var cell_size : int = 50 :   ## The nominal size for the background pattern.
	set(val):
		cell_size = val
		queue_redraw()
@export var min_cell_size : int = 8 :  ## As you zoom out and cells become smaller, how small until we just don't bother rendering?
	set(val):
		min_cell_size = clamp(val, 1, cell_size)
		queue_redraw() 
@export var grid_thick : int = 2 :  ## Width of the lines for drawing background pattern.
	set(val):
		grid_thick = clamp(val, -1, min_cell_size)
		queue_redraw() 
@export var orig_thick : int = 4 :  ## Width of the lines for drawing the origin indicator.
	set(val):
		orig_thick = clamp(val, -1, min_cell_size)
		queue_redraw() 
@export var lasso_thick : int = 6 ## Width of the lines of the selection box.
@export var grid_color := Color.BLACK :  ## Color of background pattern lines.
	set(val):
		grid_color = val
		queue_redraw() 
@export var orig_color := Color.RED :  ## Color of the lines for the origin indicator.
	set(val):
		orig_color = val
		queue_redraw() 
@export var lasso_main_color := Color.WEB_GREEN  ## First color for the selection box.
@export var lasso_alter_color := Color.YELLOW  ## Second color for the selection box.
@export var chirality := CHIRAL.NONE ## What type of selection can be done.

enum CHIRAL{
	NONE, ## Just a main color selection lasso is used.
	HORIZONTAL, ## Lasso type is different if dragging starts from right or left.
	VERTICAL, ## Lasso type is different if dragging starts from the top or the bottom.
}

#region Boilerplate
var _camera : Camera2D
var _nodes : Node
var forecanvas : Control
var overlay : Control
var center : Vector2
func _init():
	if not item_rect_changed.is_connected(_on_rect_changed):
		item_rect_changed.connect(_on_rect_changed)
	_camera = Camera2D.new()
	_camera.limit_enabled = false
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	zoom = _camera.zoom.x
	_nodes = Node.new()
	_nodes.name = "_NODES_"
	var subviewportcontainer := SubViewportContainer.new()
	subviewportcontainer.stretch = true
	var subviewport := SubViewport.new()
	subviewport.transparent_bg = true
	subviewportcontainer.add_child(subviewport)
	subviewport.add_child(_camera)
	subviewport.add_child(_nodes)
	add_child(subviewportcontainer)
	_nodes.owner = self
	subviewportcontainer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	forecanvas = Control.new()
	forecanvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(forecanvas)
	forecanvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	forecanvas.draw.connect(draw_fore_geometry)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.draw.connect(draw_overlay)


func _on_rect_changed():
	center = get_rect().get_center()
	#_camera.offset = center

var lasso_mode : bool  ## Type of selection last drawn. Depends on [code]chirality[/code].
var lasso_screen_rect : Rect2 :  ## This is the area of the last box selection. Only updated when the selection operation ends. Even outside lassoing operations, this variable is still computed as it provides utility to mouse drag operations in general.
	set(val):
		lasso_screen_rect = val
		lasso_canvas_rect = to_canvas_rect(val)
var lasso_canvas_rect : Rect2  ## This the area of the last box selection performed, and is being performed; it updates as the box is drawn. Even outside lassoing operations, this variable is still computed as it provides utility to mouse drag operations in general.


#region Canvas Handling
var origin := Vector2.ZERO :  ## position in Canvas frame of reference.
	set(val):
		_origin_moved(origin, val)
		origin = val
		_camera.position = -val
		queue_redraw()
	get():
		return -_camera.position
var zoom : float = 0.0 : set=set_zoom

func set_zoom(val:float):
		zoom = clamp(val, 0.25, 4)
		_camera.zoom = Vector2.ONE * zoom
		queue_redraw()

func go_to(canvas_coord:Vector2):
	origin = canvas_coord + center * zoom

## What's the position local to the ColorRect of the Canvas frame origin.
func to_screen_coord(canvas_coord:Vector2, offset := Vector2.ZERO) -> Vector2:
	return (origin + offset + canvas_coord) * zoom

## What's the position in Canvas frame of a local position value.
func to_canvas_coord(screen_coord:Vector2, offset:=Vector2.ZERO) -> Vector2:
	screen_coord /= zoom
	return screen_coord - origin + offset

func to_screen_rect(canvas_rect:Rect2) -> Rect2:
	var rect = Rect2()
	rect.position = to_screen_coord(canvas_rect.position)
	rect.end = to_screen_coord(canvas_rect.end)
	return rect

func to_canvas_rect(screen_rect:Rect2) -> Rect2:
	var rect = Rect2()
	rect.position = to_canvas_coord(screen_rect.position)
	rect.end = to_canvas_coord(screen_rect.end)
	return rect
#endregion

#region Object Management

#region Object selection
signal objects_selected(objects:Array)

var _selected : Dictionary  ## Objects in the canvas that the user selects as a group or individually.[br] Don't write directly to this variable use [code]*_selected()[/code] functions instead.
var obj_groups : Dictionary[StringName, Array] ## Objects which are grouped together such as they always move or are selected together.

func set_selected(...objs):
	_selected.clear()
	for obj in objs:
		if obj == null: continue
		var pos := Vector2.ZERO
		if "position" in obj: pos = obj.position
		elif obj is Object:
			if obj.has_method("get_rect"): pos = obj.get_rect().position
			elif "rect" in obj: pos = obj.rect
		else:
			if "rect" in obj: pos = obj.rect
		
		_selected[obj] = get_obj_data(obj).get_or_add("position", pos)
		objects_selected.emit(_selected.keys())
		selected_changed()

func add_selected(...objs):
	for obj in objs:
		if obj == null: continue
		var pos := Vector2.ZERO
		if "position" in obj: pos = obj.position
		elif obj is Object:
			if obj.has_method("get_rect"): pos = obj.get_rect().position
			elif "rect" in obj: pos = obj.rect
		else:
			if "rect" in obj: pos = obj.rect
		_selected[obj] = get_obj_data(obj).get_or_add("position", pos)
		selected_changed()

func rem_selected(...objs):
	var ini_count = _selected.size()
	for obj in objs:
		_selected.erase(obj)
	if ini_count != _selected.size():
		selected_changed()

func clear_selected():
	var ini_count = _selected.size()
	_selected.clear()
	if ini_count != _selected.size():
		selected_changed()

func selected_changed():
	queue_redraw()
	_selected_changed()

func _selected_changed():
	pass
#endregion

## Register an object to a partition and sets its position, if possible. If no partition is provided, it uses a default one.[br]
## Objects can be anything which contains a [code]position[/code] key or property, or a [code]rect[/code] key or property.
## This includes Dictionaries like [code]{"position"=Vector2.ZERO}[/code], instances of inner classes and obviously, normal classes like Godot nodes.
## Returns the partition data of that object, where options can be changed. If the object changes position, call [code]SpatialPartition.update_object()[/code].
func place_object(obj, canvas_coord:Vector2, partition:SpatialPartition=parti[0 as Variant]) -> Dictionary:
	all_objs[obj] = partition
	var data = partition.add_object(obj, canvas_coord)
	if obj is Node:
		_nodes.add_child(obj)
		obj.owner = self
	if "position" in obj:
		obj.position = canvas_coord
	if "rect" in obj: obj.rect.position = canvas_coord
	return data

## Removes an object from its partition. If the object is a Godot node, it must
## be [code]queue_free()[code] independently.
func remove_object(obj) -> Dictionary:
	var partition = all_objs.get(obj, parti[0 as Variant])
	all_objs.erase(obj)
	var data = partition.remove_object(obj)
	if obj is Node:
		_nodes.remove_child(obj)
	return data
#endregion

#region Drawing Functions
var _view_rect : Rect2
func _draw():
	var local_origin = to_screen_coord(Vector2.ZERO)
	var view_x = local_origin.x > 0 and local_origin.x < size.x
	var view_y = local_origin.y > 0 and local_origin.y < size.y
	
	_view_rect = to_canvas_rect(Rect2(Vector2.ZERO, size))
	
	draw_background_pattern(self, local_origin, to_screen_coord(Vector2.ONE * cell_size, -origin).x)
	draw_origin_axis(self, view_x, view_y, local_origin)
	if not (view_x and view_y):
		draw_compass(self)
	
	draw_back_geometry(self, _view_rect)
	highlight_objects(self, _selected.keys())
	forecanvas.queue_redraw()
	overlay.queue_redraw()
	
	if DEBUGGING:
		## This shows a blue rectangle of the `canvas_rect` given to `draw_*_geometry()` (a little shrunk for better visibility).
		## Then checkered green and orange squares are the partitions being being searched according to that `canvas_rect`.
		## The red squares are also searched, but are at the limits of what is searched, so there's no doubt about whether the search area is too big or not.
		## `find_objects()` will return any object in any of the squares.
		## `find_objects_simple()` will return those which top-left corner (position coordinate) stay inside the blue.
		## `find_objects_tolerant()` will return the objects which bounding rect still touches the blue, but not if completely outside.
		## `find_objects_zealous()` will return the objects which bounding rect is completely inside the blue.
		
		var start = parti[0 as Variant].make_partition_id(_view_rect.position) - Vector2i.ONE * 1
		var stop = parti[0 as Variant].make_partition_id(_view_rect.end) + Vector2i.ONE * 1
		var parti_size = Vector2.ONE * parti[0 as Variant].root_size
		for x in range(start.x, stop.x):
			for y in range(start.y, stop.y):
				var rect = Rect2(
					Vector2(x,y) * parti_size,
					parti_size
					)
				var c = [Color.LIME_GREEN, Color.ORANGE][int(x % 2 == 0) ^ int(y % 2 == 0)]
				if x <= start.x or x >= stop.x - 1 or y <= start.y or y >= stop.y - 1:
					c = Color.DARK_RED
				rect = to_screen_rect(rect).grow(-6)
				draw_rect(rect, c, false, 6)
		draw_rect(to_screen_rect(_view_rect).grow(-20), Color.BLUE, false, 2)

## The grid pattern, or whatever else, if overriden.
func draw_background_pattern(canvas:Control, offset:Vector2, spacing:float):
	if spacing > min_cell_size:  # Don't draw stuff if it all gets bunched up.
		
		offset.x = fmod(offset.x, spacing)
		offset.y = fmod(offset.y, spacing)
		
		var grid : PackedVector2Array
		var coverage : float = 0
		while coverage < size.x + spacing:
			var stride = coverage + offset.x
			grid.append(Vector2(stride, 0))
			grid.append(Vector2(stride, size.y))
			coverage += spacing
		coverage = 0
		while coverage < size.y + spacing:
			var stride = coverage + offset.y
			grid.append(Vector2(0, stride))
			grid.append(Vector2(size.x, stride))
			coverage += spacing
		
		var true_thick = float(grid_thick) * zoom
		if true_thick <= 1:  # if line thickness is less than one pixel, just render always at one pixel
			true_thick = -1
		canvas.draw_multiline(grid, grid_color, true_thick)

## Draw lines towards the origin.
func draw_origin_axis(canvas:Control, x_visible:bool, y_visible:bool, offset:Vector2):
	if x_visible:  # Vertical Origin Line
		canvas.draw_dashed_line(Vector2(offset.x, 0), Vector2(offset.x, size.y), orig_color, orig_thick, cell_size * 0.2)
	if y_visible:  # Horizontal Origin Line
		canvas.draw_dashed_line(Vector2(0, offset.y), Vector2(size.x, offset.y), orig_color, orig_thick, cell_size * 0.2)

## Draw a Compass towards the origin.
func draw_compass(canvas:Control):
	var compass_dir : Vector2 = center.direction_to(origin)
	
	var max_axis = compass_dir.abs().max_axis_index()
	var sticky_side : float = [Vector2.RIGHT, Vector2.DOWN][max_axis].dot(compass_dir)
	sticky_side = [50, size[max_axis] - 50][int(sticky_side >= 0)]
	
	var min_axis = compass_dir.abs().min_axis_index()
	var sliding_side : float = [Vector2.RIGHT, Vector2.DOWN][min_axis].dot(compass_dir) + 1
	sliding_side = sliding_side * (size[min_axis] - 50) * 0.5

	var compass_pos : Vector2
	compass_pos[min_axis] = sliding_side
	compass_pos[max_axis] = sticky_side
	
	var arc_span : float = PI * 0.35
	canvas.draw_arc(compass_pos, 27, compass_dir.angle() - arc_span, compass_dir.angle() + arc_span, 3, orig_color, 12)

func draw_lasso(canvas:Control):  # Drawn on the overlay, so we don't have to do `queue_redraw()` on mouse motion
	canvas.draw_rect(lasso_screen_rect, [lasso_main_color, lasso_alter_color][int(lasso_mode)], false, lasso_thick)

## Draw highlight effect on selected objects. Objects where the Rect2 doesn't have area are ignored.
func highlight_objects(canvas:Control, selected_objs:Array):
	for obj in selected_objs:
		var rect = get_obj_rect(obj)
		if rect.size == Vector2.ZERO: continue
		rect.position = to_screen_coord(rect.position)
		rect.size *= zoom
		canvas.draw_rect(rect, color.inverted(), false, lasso_thick)
#endregion

#region Helper Functions
func get_obj_data(obj) -> Dictionary:
	return all_objs[obj].get_obj_data(obj)


## Return a Rect2 for object, enabling a way to tell if an object still counts as within selection, even if it's origin coordinate would be excluded.
func get_obj_rect(obj) -> Rect2:
	return all_objs[obj].get_obj_rect(obj)

#endregion

#region Override Functions
## Decide if something happens when the canvas origin is changed.
@warning_ignore("unused_parameter")
func _origin_moved(past:Vector2, future:Vector2):
	pass

func draw_back_geometry(canvas:Control, viewed_canvas_rect:Rect2):
	_draw_back_geometry(canvas, viewed_canvas_rect)

## Objects in partitions might not have an intrinsic visual representation, like Godot Nodes do.
## How you override [code]draw_*_geometry()[/code] defines how to interpret the object's data.[br]
## This draws behind child nodes.
@warning_ignore("unused_parameter")
func _draw_back_geometry(canvas:Control, viewed_canvas_rect:Rect2):
	pass

func draw_fore_geometry():
	#NOTE This is called by a signal on `forecanvas`.
	_draw_fore_geometry(forecanvas, _view_rect)

## Objects in partitions might not have an intrinsic visual representation, like Godot Nodes do.
## How you override [code]draw_*_geometry()[/code] defines how to interpret the object's data.[br]
## This draws in front child nodes, by using draw calls on [code]canvas[/code].
@warning_ignore("unused_parameter")
func _draw_fore_geometry(canvas:Control, viewed_canvas_rect:Rect2):
	pass

@warning_ignore("unused_parameter")
func draw_overlay():
	#NOTE This is called by a signal on `overlay`.
	_draw_overlay(overlay, _view_rect)

## This draws in front of everything, by using draw calls on [code]canvas[/code].[br]
## This is similar to [code]draw_fore_geometry[/code], but updates independently,
## intended for re-drawing at high frequency, like effects on mouse motion.[br]
## See [code]overlay[/code] for more information.
@warning_ignore("unused_parameter")
func _draw_overlay(canvas:Control, viewed_canvas_rect:Rect2):
	pass

#endregion
