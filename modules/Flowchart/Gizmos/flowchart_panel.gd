@tool
extends Control
class_name FlowchartPanel

## A scene node that can be added to a Flowchart (using [code]Flowchart.add_gizmo()[/code])
## It defines layout and acts as a carrier for Control nodes to have common interface
## with the Flowchart.[br]
## You may override [code]_cycle_update()[/code] to do something during a simulation frame.[br]
## The size of a Panel is always a multiple of the Flowchart grid snapping.[br]
## In editor it can also display a grid of socket positions things may snap to.
## The layout system works by implementing [code]_update_layout()[/code], change
## the position of objects to move them around, and the [code]panels[/code] property
## to decide which panels to display.[br]
## The background is a procedurally generated set of StyleBox defined in
## [code]panelstyle[/code], and positioned with [code]panelrect[/code], according to
## [code]panels[/code] indexes. The same StyleBox can be reused for different Rect2.[br]
## Child UI controls are typically disabled if [code]Flowchart.mode[/code] is
## [code]Flowchart.Mode.EDITING[/code], allowing to drag and move them, without
## changing their state accidentally. If a child Control node is meant to
## receive events during schematic editing, place a [code]bool[/code] type metadata
## called "edit_control" set to [code]true[/code]. If it shouldn't be enabled
## during simulation add the metadata "edit_only_control" instead.[br]
## You may have controls hide when disabled with the metadata "hide_on_disable".[br]
## You may also make child controls' anchors bound to the grid with the metadata
## "grid_bound" associated to a Vector2 and it will respect the same rules as panel Rect2.
## The position will then be relative to these anchors. In the [code]_update_layout()[/code]
## this coordinate may be modified to make controls snap to the grid.

#TODO Disable Gizmo repositioning if clicking on controls in editing mode.

signal sim_update_done

enum FACE{
	EAST,
	SOUTH,
	WEST,
	NORTH
}

@export var facing : FACE = FACE.EAST :
	set(val):
		facing = val
		update_layout()

@export var panelstyle : Array[StyleBox] : 
	set(val):
		panelstyle = val
		for each in val:
			each.changed.connect(queue_redraw)
@export var panels : Dictionary[Vector4, int] :  ## [Vector4] -> panelstyle_idx; Tells the position and size of a stylebox by the distance of each side of a rectangle from the west and north edges. X is west side, Y is north side, Z is east side and W is bottom side.[br] This works as control interface to define which styleboxes to display depending on layout. If you don't want to show something, don't mention it!
	set(val):
		var _val : Dictionary[Vector4, int]
		for box in val:
			var style_i = val[box]
			if style_i < panelstyle.size():
				_val[box] = style_i
		panels = _val
		queue_redraw()

@export var show_grid := false : set=_set_show_grid
func _set_show_grid(val:bool):
	show_grid = val
	queue_redraw()

var layer : int = 0  ## Flowchart layer this Gizmo sits
var _mouse_hover : bool : set=_set_mouse_hover

func _set_mouse_hover(val:bool):
	_mouse_hover = val

#@onready var socket_menu := PopupMenu.new()
#@onready var socket_tooltip := PanelContainer.new()

func _canvas_repositioned(_data:Dictionary):
	_grid.position = Flowchart.to_grid(position)

func _parti_registered(_parti:SpatialPartition, data:Dictionary) -> void:
	data.registry_acknowledged = true

func _init() -> void:
	resized.connect(_on_resized)
	mouse_entered.connect(func():_mouse_hover = true)
	mouse_exited.connect(func():_mouse_hover = false)
	_on_resized()
	
	#await ready
	#add_child(socket_tooltip, false, Node.INTERNAL_MODE_FRONT)
	#socket_tooltip.hide()
	#socket_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	#socket_tooltip.z_index = 4000
	#var tooltip = Label.new()
	#tooltip.name = "Label"
	#tooltip.text = "TOOLTIPPED"
	#tooltip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	#socket_tooltip.add_child(tooltip)
	#add_child(socket_menu, false, Node.INTERNAL_MODE_FRONT)
	#socket_menu.add_check_item("Show State")


var _grid : Rect2i  ## Rect2i.position is a coordinate in flowchart.
func _on_resized():
	custom_minimum_size = custom_minimum_size.max(Vector2.ONE * Flowchart.SNAP)
	size = size.snappedf(Flowchart.SNAP)
	_grid.size.x = floori(size.x / Flowchart.SNAP)
	_grid.size.y = floori(size.y / Flowchart.SNAP)


#region Positioning things to the grid

func get_canvas_position(coord:Vector2i) -> Vector2:
	return position + Flowchart.from_grid(coord, true)

func get_canvas_coord(coord:Vector2i) -> Vector2i:
	return _grid.position + get_bound_coord(coord)

## Have a grid coordinate contained to the size of the grid. Negative values
## wrap around the size of the panel grid.
func get_bound_coord(coord:Vector2i) -> Vector2i:
	# Limit magnitude to node size, both in negative
	# and positive direction.
	coord.x = clamp(coord.x, -_grid.size.x, _grid.size.x)
	coord.y = clamp(coord.y, -_grid.size.y, _grid.size.y)
	# Wrap around to stay contained by the grid size.
	@warning_ignore("integer_division")
	coord.x = wrapi(coord.x, 0, _grid.size.x)
	@warning_ignore("integer_division")
	coord.y = wrapi(coord.y, 0, _grid.size.y)
	return coord

## Have a grid position contained to the size of the grid.[br]
## The integer part of a vector element is taken as grid cell, with decimal
## part allowing for an offset from that. Negative values wrap around the size
## of the panel grid.
func get_bound_position(pos:Vector2, centered:=false) -> Vector2:
	pos.x = get_bound_distance(pos.x, false, centered)
	pos.y = get_bound_distance(pos.y, true, centered)
	return pos

func get_bound_distance(dist:float, axis_y:bool, centered:=false) -> float:
	var dist_int = floorf(abs(dist))  # integer part of the values
	var dist_dec = dist - dist_int  # decimal part of the values
	
	# Scale with grid cell size.
	dist = Flowchart.SNAP * (dist_int + (0.5 if centered else 0.0)) + dist_dec * Flowchart.SNAP
	
	# Limit magnitude to node size, both in negative
	# and positive direction.
	dist = clamp(dist, -size[int(axis_y)], size[int(axis_y)])
	
	# Make negatives count from the end.
	dist = wrap(dist, 0.0, size[int(axis_y)] + Flowchart.SNAP)
	
	return dist
#endregion

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT:
				var existing = owner._selected.find(self)
				if Input.is_key_pressed(KEY_CTRL):
					if existing < 0:
						owner._selected += [self]
					else:
						owner._selected.remove_at(existing)
				elif existing < 0:
					owner._selected = [self]


@warning_ignore_start("unused_parameter")
func sim_update(graph:FlowchartNetwork):
	_sim_update(graph)
	sim_update_done.emit()
func _sim_update(graph:FlowchartNetwork):
	pass


var _layout_outdated : bool
## Override this function to define the layout.
func _update_layout(): pass
## Call this function if something changed that affects layout. If Sockets were
## Altered, call [code]_update_sockdex()[/code] first.
func update_layout():
	queue_redraw()
	_layout_outdated = true

func rotate(clockwise:bool) -> void:
	orientation((facing + (1 if clockwise else -1)) % 4)
	_rotate(clockwise)
	update_layout()
func mirror(axis_y:bool) -> void:
	_mirror(axis_y)
	update_layout()
func orientation(towards:FACE) -> void:
	var prev = facing
	facing = towards
	_orientation(prev, towards)
	update_layout()
func _rotate(clockwise:bool) -> void:
	pass
func _mirror(axis_y:bool) -> void:
	pass
func _orientation(previous:FACE, towards:FACE) -> void:
	pass

func _process(_delta: float) -> void:
	if _layout_outdated:
		if not is_node_ready():await ready
		_layout_outdated = false
		_update_layout()

func _draw() -> void:
	for each in get_children():
		if each is Control:
			var coord = each.get_meta("grid_bound", false)
			if typeof(coord) == TYPE_BOOL: continue
			#TODO Change anchors instead of position.
			var where = get_bound_position(coord)
			each.position = where
	
	for box : Vector4 in panels:
		var style = panelstyle[panels[box]]
		box.x = get_bound_distance(box.x, false, false)
		box.y = get_bound_distance(box.y, true, false)
		box.z = get_bound_distance(box.z, false, false)
		box.w = get_bound_distance(box.w, true, false)
		
		var rect = Rect2(box.x, box.y, 0, 0)
		rect.end = Vector2(box.z, box.w)
		draw_style_box(style, rect)
	
	if OS.has_feature("editor_hint"):
		# Visual helper to tell the grid cells
		if show_grid:
			for y : int in range(_grid.size.y):
				for x : int in range(_grid.size.x):
					var pos = Flowchart.from_grid(Vector2i(x,y), true)
					draw_circle(pos, Flowchart.JOINT_RAD, Color.HOT_PINK, false)
	elif owner is Flowchart:
		# Allow socket effects to update when it's the Flowchart drawing them.
		owner.queue_redraw()


func _on_flowchart_mode_changed(mode:Flowchart.Mode):
	match mode:
		Flowchart.Mode.EDITING:
			# Allow re-positioning and wiring
			mouse_filter = MOUSE_FILTER_STOP
			for each in get_children():
				if not each is Control: continue
				if each.get_meta("edit_control", false) or each.get_meta("edit_only_control", false):
					if each.get_meta("hide_on_disable", false):
						each.show()
					each.mouse_behavior_recursive = MOUSE_BEHAVIOR_ENABLED
				else:
					if each.get_meta("hide_on_disable", false):
						each.hide()
					each.mouse_behavior_recursive = MOUSE_BEHAVIOR_DISABLED
		Flowchart.Mode.SIMULAT:
			# Allow interacting which children UI
			mouse_filter = MOUSE_FILTER_IGNORE
			for each in get_children():
				if not each is Control: continue
				if each.get_meta("edit_only_control", false):
					if each.get_meta("hide_on_disable", false):
						each.hide()
					each.mouse_behavior_recursive = MOUSE_BEHAVIOR_DISABLED
				else:
					if each.get_meta("hide_on_disable", false):
						each.show()
					each.mouse_behavior_recursive = MOUSE_BEHAVIOR_ENABLED
