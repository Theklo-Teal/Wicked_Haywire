@tool
extends Control
class_name FlowchartPanel

## A scene node that can be added to a Flowchart (using [code]Flowchart.add_gizmo()[/code])
## It defines layout and acts as a carrier for Control nodes to have common interface
## with the Flowchart.[br]
## You may override [code]_cycle_update()[/code] to do something during a simulation frame.[br]
## The size of a Panel is always a multiple of the Flowchart grid snapping.[br]
## In editor it can also display a grid of socket positions that "surfaces" snap to.
## Objects can be positioned relative to these surfaces. The layout system changes
## the surface assoicated with objects to move them around.[br]
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
## The position will then be relative to these anchors.

#TODO Disable Gizmo repositioning if clicking on controls in editing mode.

signal sim_update_done

@export var show_grid := false : set=_set_show_grid
func _set_show_grid(val:bool):
	show_grid = val
	queue_redraw()

@export var panelstyle : Array[StyleBox] : 
	set(val):
		panelstyle = val
		for each in val:
			each.changed.connect(queue_redraw)
@export var panelrect : Array[Rect2] :  ## The placement of panels. The units are in snap units, but values in between grid cells are allowed. For example, w = 3.0, makes a panel (snap * 3) of width, but w = 3.5 makes it between grid cells, (snap * 3 + snap * 0.5). If size is negative or zero, the value will be relative to size of the node.
	set(val):
		panelrect = val
		queue_redraw()
@export var panels : Dictionary[int, int] :  ## [panelrect_idx] -> panelstyle_idx; Association between panelrect to their intended styleboxes. This works as control interface to define which styleboxes to display depending on layout. If you don't want to show something, don't mention it!
	set(val):
		var _val : Dictionary[int, int]
		for rect_i in val:
			var style_i = val[rect_i]
			if rect_i < panelrect.size() and style_i < panelstyle.size():
				_val[rect_i] = style_i
		panels = _val
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
func get_bound_position(pos:Vector2) -> Vector2:
	var pos_int = pos.floor()  # integer part of the values
	var pos_dec = pos - pos_int  # decimal part of the values
	
	# Scale with grid cell size.
	pos = Flowchart.from_grid(pos_int, true) + pos_dec * Flowchart.SNAP
	
	# Limit magnitude to node size, both in negative
	# and positive direction.
	pos.x = clamp(pos.x, -size.x, size.x)
	pos.y = clamp(pos.y, -size.y, size.y)
	
	# Make negatives count from the end.
	pos.x = wrap(pos.x, 0.0, size.x + Flowchart.SNAP)
	pos.y = wrap(pos.y, 0.0, size.y + Flowchart.SNAP)
	
	return pos
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
func _update_layout(): pass
func update_layout():
	queue_redraw()
	_layout_outdated = true

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
	
	for rect_i : int in panels:
		var style_i = panels[rect_i]
		var rect = panelrect[rect_i]
		var style = panelstyle[style_i]
		var pos_floor = rect.position.floor()
		var siz_floor = rect.size.abs().floor()
		var pos_deci = rect.position - pos_floor
		var siz_deci = (rect.size.abs() - siz_floor) * rect.size.sign()
		siz_floor *=  rect.size.sign()
		
		# Scale to the grid
		rect.position = pos_floor * Flowchart.SNAP + Flowchart.SNAP * pos_deci
		rect.size = siz_floor * Flowchart.SNAP + Flowchart.SNAP * siz_deci
		
		rect.position.x = clamp(rect.position.x, -Flowchart.SNAP, size.x)
		rect.position.y = clamp(rect.position.y, -Flowchart.SNAP, size.y)
		
		# Expand with node size.
		var max_end = size + Vector2(2,2) * Flowchart.SNAP
		rect.end.x = wrap(rect.end.x, rect.position.x + Flowchart.SNAP, max_end.x)
		rect.end.y = wrap(rect.end.y, rect.position.y + Flowchart.SNAP, max_end.y)
		
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
			mouse_filter = Control.MOUSE_FILTER_STOP
			for each in get_children():
				if each.get_meta("edit_control", false) or each.get_meta("edit_only_control", false):
					if each.get_meta("hide_on_disable", false):
						each.show()
					each.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
				else:
					if each.get_meta("hide_on_disable", false):
						each.hide()
					each.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		Flowchart.Mode.SIMULAT:
			# Allow interacting which children UI
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			for each in get_children():
				if each.get_meta("edit_only_control", false):
					if each.get_meta("hide_on_disable", false):
						each.hide()
					each.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
				else:
					if each.get_meta("hide_on_disable", false):
						each.show()
					each.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
