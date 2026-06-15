@tool
extends Container
class_name FlowchartNode

## A panel containing sockets to be added to Flowchart and FlowchartGraph.[br]
## Any Control children with [code]size_flags_*[/code] set to "FILL" will expand
## to this node's size. If they have "EXPAND" set, their size will affect this
## node's size. To manually set a size for this node, use [code]custom_minimum_size[/code]
## and it will snap to the closest multiple of [code]G.grid_size[/code].[br]
## A grid is drawn in editor to display the cells of this panel's grid.
## Sockets always snap to this grid.[br]
## Stylebox panels can be defined to be drawn as a background with [code]panels[/code]
## Which associates a [code]panelstyle[/code] index to a [code]panelsrect[/code]
## index.[br]
## Child nodes generally stick to beginning, center, end according to [code]size_flags_*[/code]
## but can be offset to grid coordinates if they hold a metadata variable [code]grid_pos[/code]
## as a [code]Vector2[/code]. The units accept in-between coordinates and negative
## values similar to background panels' size.[br]
## Child nodes with the metadata [code]bool[/code] set [code]true[/code] of
## "floater_panel", makes the child coordinates to be outside the node's bounding
## box, relative to its edges.
## Child UI controls are typically disabled if [code]Flowchart.mode[/code] is
## [code]Flowchart.Mode.EDITING[/code], allowing to drag and move them, without
## changing their state accidentally. If a child Control node is meant to
## receive events during schematic editing, place a [code]bool[/code] type metadata
## called "edit_control" set to [code]true[/code]. If it shouldn't be enabled
## during simulation add the metadata "edit_only_control" instead.[br]
## You may have controls hide when disabled with the metadata [code]hide_on_disable[/code].

#TODO Improve positioning of grid-aligned children.

#FIXME Socket resources are shared by all instances of same chart node!

signal update_done
signal begin_done
signal finish_done

@export var panelstyle : Array[StyleBox]
@export var panelrect : Array[Rect2] :  ## The placement of panels. The units are in grid_size units, but values in between grid cells are allowed. For example, w = 3.0, makes a panel (grid_size * 3) of width, but w = 3.5 makes it between grid cells, (grid_size * 3 + grid_size * 0.5). If size is negative or zero, the value will be relative to size of the node.
	set(val):
		panelrect = val
		queue_redraw()
@export var panels : Array[int] :  ## [panelrect_idx] -> panelstyle_idx; Association between panelrect to their intended styleboxes.
	set(val):
		var _val : Array[int]
		for r in val:
			var s = val[r]
			if r < panelrect.size() and s < panelstyle.size():
				_val.append(s) 
		panels = _val
		queue_redraw()

@export var sockets : Array[ChartSocket]:
	set(val):
		sockets = val
		if not is_node_ready():
			await sort_children
		_sockdex.clear()
		for sock : ChartSocket in sockets:
			register_socket(sock)
var _sockdex : Dictionary[Vector2i, ChartSocket]  # Back reference to find which socket is in at certain coord.
func register_socket(socket:ChartSocket): 
	if  socket != null:
		if not socket.changed.is_connected(_on_socket_changed):
			socket.changed.connect(_on_socket_changed.bind(socket))
		_sockdex[get_socket_true_coord(socket)] = socket
		#if owner is Flowchart:
		#	owner.graph.add_socket(socket, self)

func _on_socket_changed(_sock:ChartSocket):
	queue_sort()


func _parti_registered(data:Dictionary) -> void:
	add_to_group("grid_size_response")
	data.registry_acknowledged = true


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


var grid_span : Vector2i
func _notification(what):
	if what == NOTIFICATION_SORT_CHILDREN: # Must re-sort the children
		queue_redraw()
		reset_size()
		size = Vector2.ONE * G.grid_size
		for c in get_children():
			# Fit to the children's size.
			if c is Control and c.visible:
				if c.size_flags_horizontal & SIZE_EXPAND > 0:
					size.x = max(size.x, c.position.x + c.size.x)
				if c.size_flags_vertical & SIZE_EXPAND > 0:
					size.y = max(size.y, c.position.x + c.size.y)
		size = size.snappedf(G.grid_size)
		for c in get_children():
			var c_pos= c.get_meta("grid_pos", Vector2.ZERO) * G.grid_size
			if c is Control:
				c.reset_size()
				
				# Horizontal Positioning
				if c.size_flags_horizontal & SIZE_FILL > 0:
					c.size.x = size.x
				elif c.get_meta("floater_panel", false):
					if c_pos > 0:
						c.position.x = wrap(size.x + c_pos.x, size.x, c.size.x)
					else:
						c.position.x = wrap(c_pos.x, -size.x * 2, -size.x)
				else:
					if c.size_flags_horizontal & SIZE_SHRINK_CENTER > 0:
						var center = size.x / 2 - c.size.x / 2
						c.position.x = wrap(c_pos.x + center, 0, size.x)
					elif c.size_flags_horizontal & SIZE_SHRINK_END > 0:
						c.position.x = wrap(size.x - c_pos.x, 0, size.x - c.size.x)
					else:  # Equivalent t0 SIZE_SHRING_BEGIN
						c.position.x = wrap(c_pos.x, 0, size.x)
				
				# Vertical Positioning
				if c.size_flags_vertical & SIZE_FILL > 0:
					c.size.y = size.y
				elif c.get_meta("floater_panel", false):
					if c_pos > 0:
						c.position.y = wrap(size.y + c_pos.y, size.y, c.size.y)
					else:
						c.position.y = wrap(c_pos.y, -size.y * 2, -size.y)
				else:
					if c.size_flags_vertical & SIZE_SHRINK_CENTER > 0:
						var center = size.y / 2 - c.size.y / 2
						c.position.y = wrap(c_pos.y + center, 0, size.y)
					elif c.size_flags_vertical & SIZE_SHRINK_END > 0:
						c.position.y = wrap(size.y - c_pos.y, 0, size.y)
					else: # Equivalent t0 SIZE_SHRING_BEGIN
						c.position.y = wrap(c_pos.y, 0, size.y)
		
		grid_span.x = floori(size.x / G.grid_size)
		grid_span.y = floori(size.y / G.grid_size)


#region Drawing Background
func _draw() -> void:
	
	if OS.has_feature("editor_hint"):
		# Visual helper to tell the grid cells
		for x in range(0, size.x, G.grid_size):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color.HOT_PINK)
		for y in range(0, size.y, G.grid_size):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color.HOT_PINK)
	
	for p : int in panels:
		var rect = panelrect[p]
		var style = panelstyle[panels[p]]
		var pos_floor = rect.position.floor()
		var siz_floor = rect.size.abs().floor()
		var pos_deci = rect.position - pos_floor
		var siz_deci = (rect.size.abs() - siz_floor) * rect.size.sign()
		siz_floor *=  rect.size.sign()
		
		# Scale to the grid
		rect.position = pos_floor * G.grid_size + G.grid_size * pos_deci
		rect.size = siz_floor * G.grid_size + G.grid_size * siz_deci
		
		rect.position.x = clamp(rect.position.x, -G.grid_size, size.x)
		rect.position.y = clamp(rect.position.y, -G.grid_size, size.y)
		
		# Expand with node size.
		var max_end = size + Vector2(2,2) * G.grid_size
		rect.end.x = wrap(rect.end.x, rect.position.x + G.grid_size, max_end.x)
		rect.end.y = wrap(rect.end.y, rect.position.y + G.grid_size, max_end.y)
		
		draw_style_box(style, rect)
		
	for sock : ChartSocket in sockets:
		if sock != null:
			var sock_pos = get_socket_position(sock)
			sock.draw(self, sock_pos)

#endregion

#region Socket Managment
# Get the grid coord of socket, after computing negative values
func get_socket_true_coord(sock:ChartSocket):
	var true_coord = sock.coord
	true_coord.x = wrapi(true_coord.x, 0, grid_span.x)
	true_coord.y = wrapi(true_coord.y, 0, grid_span.y)
	return true_coord

## Get a socket position from its instance
func get_socket_position(socket:ChartSocket) -> Vector2:
	return get_socket_position_from_coord(socket.coord)
## Get a socket position from its Grid Coordinate
func get_socket_position_from_coord(socket_coord:Vector2i) -> Vector2:
	var pos := Vector2(socket_coord)
	pos *= G.grid_size
	pos.x = wrap(pos.x, 0, size.x) + G.grid_size * 0.5
	pos.y = wrap(pos.y, 0, size.y) + G.grid_size * 0.5
	return pos

func get_socket_canvas_position(socket:ChartSocket) -> Vector2:
	return get_socket_position(socket) + position


func add_graph_socket(socket : ChartSocket, coord := Vector2i.ZERO):
	socket.coord = coord
	sockets.append(socket)
	register_socket(socket)
	queue_sort()

func rem_graph_socket(socket : ChartSocket):
	if owner is Flowchart:
		owner.clear_wires(socket)
		owner.graph.rem_socket(socket)
	_sockdex.erase(get_socket_true_coord(socket))
	sockets.erase(socket)
	queue_sort()
#endregion

#region Input Events
var _mouse_hover : bool
func _init() -> void:
	
	mouse_entered.connect(func():_mouse_hover = true)
	if not mouse_exited.is_connected(_on_mouse_exit):
		mouse_exited.connect(_on_mouse_exit)
func _on_mouse_exit():
	_mouse_hover = false
	if hover_socket != null:
		hover_socket.pressed=false
		hover_socket.hover=false
		hover_socket = null
		queue_redraw()
	
func on_grid_size_changed():
	queue_sort()

#region Detect when the mouse stops moving
var mouse_moving := false
var mouse_moved := false
func _process(_delta: float) -> void:
	if mouse_moving:
		mouse_moving = false
		mouse_moved = true
	elif mouse_moved:
		mouse_moved = false
		_on_mouse_stopped()

var hover_socket : ChartSocket : 
	set(val):
		if val != hover_socket:
			queue_redraw()
		hover_socket = val
func _on_mouse_stopped():
	# Check if mouse is over a socket.
	var cell = (get_local_mouse_position() - Vector2(0.5, 0.5) * G.grid_size).snappedf(G.grid_size)
	var sock = _sockdex.get(Vector2i(cell / G.grid_size))
	if hover_socket != null and hover_socket != sock:
		queue_redraw()
		hover_socket.hover = false
		hover_socket = null
	if sock != null:
		queue_redraw()
		hover_socket = sock
		sock.hover = true

#endregion

func _input(event: InputEvent) -> void:
	if _mouse_hover and G.mode == Flowchart.Mode.EDITING:
		if event is InputEventMouseMotion:
			mouse_moving = true
			
			queue_redraw()
		if event is InputEventMouseButton and owner is Flowchart:
			if hover_socket != null and event.button_index == MOUSE_BUTTON_LEFT:
				if event.is_pressed():
					queue_redraw()
					hover_socket.pressed = true
					_on_socket_pressed(hover_socket)
				elif event.is_released():
					queue_redraw()
					hover_socket.pressed = false
					_on_socket_released(hover_socket)

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

func _on_socket_pressed(socket:ChartSocket):
	var sock_data = {
		"node":self,
		"idx": sockets.find(socket),
		"local_coord": get_socket_position(socket),
		"canvas_coord": get_socket_canvas_position(socket),
		}
	if sock_data.idx >= 0:
		owner.start_socket_wiring(sock_data)
func _on_socket_released(socket:ChartSocket):
	var sock_data = {
		"node":self,
		"idx": sockets.find(socket),
		"local_coord": get_socket_position(socket),
		"canvas_coord": get_socket_canvas_position(socket),
		}
	if sock_data.idx >= 0:
		owner.stop_socket_wiring(sock_data)

#endregion

#region Simulation Override Functions
@warning_ignore_start("unused_parameter")
func update(graph:FlowchartGraph):
	_update(graph)
	update_done.emit()

func cycle_begin():
	_cycle_begin()
	begin_done.emit()

func cycle_finish():
	_cycle_finish()
	finish_done.emit()


func _update(graph:FlowchartGraph):
	pass

func _cycle_begin():
	pass

func _cycle_finish():
	pass
#endregion
