@tool
extends Control
class_name FlowchartGizmo

## A panel containing ChartSockets to be added to Flowchart and FlowchartNetwork.[br]
## The size of a Gizmo is always a multiple of the grid snapping. Any sockets will
## also snap to the grid. Position is presumably snapped to the grid by Flowchart.
## You may see the available grid cells in editor if [code]show_grid[/code] is enabled.
## Stylebox panels can be defined to be drawn as a background with [code]panels[/code]
## Which associates a [code]panelstyle[/code] index to a [code]panelsrect[/code]
## index. So the same stylebox could be used for different rectangles.[br]
## Child UI controls are typically disabled if [code]Flowchart.mode[/code] is
## [code]Flowchart.Mode.EDITING[/code], allowing to drag and move them, without
## changing their state accidentally. If a child Control node is meant to
## receive events during schematic editing, place a [code]bool[/code] type metadata
## called "edit_control" set to [code]true[/code]. If it shouldn't be enabled
## during simulation add the metadata "edit_only_control" instead.[br]
## You may have controls hide when disabled with the metadata "hide_on_disable".

#FIXME Socket resources are shared by all instances of same chart node!

signal update_done
signal begin_done
signal finish_done
@export var show_grid := false :
	set(val):
		show_grid = val
		queue_redraw()
@export var panelstyle : Array[StyleBox]
@export var panelrect : Array[Rect2] :  ## The placement of panels. The units are in snap units, but values in between grid cells are allowed. For example, w = 3.0, makes a panel (snap * 3) of width, but w = 3.5 makes it between grid cells, (snap * 3 + snap * 0.5). If size is negative or zero, the value will be relative to size of the node.
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

@export var sockets : Dictionary[ChartSocket, Vector2i] : 
	set(val):
		queue_redraw()
		val.erase(null)
		sockets = val
		_sockdex.clear()
		for sock in sockets:
			var coord = sockets[sock]
			sock.coord = coord
			sock._position = get_socket_position_from_coord(coord)
			_sockdex[get_socket_true_coord(coord)] = sock

var _sockdex : Dictionary[Vector2i, ChartSocket]  # Back reference to find which socket is in at certain coord.

func _parti_registered(data:Dictionary) -> void:
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


var _grid : Vector2i
func _on_resized():
	custom_minimum_size = custom_minimum_size.max(Vector2.ONE * G.snap)
	for sock in sockets:
		var coord = sockets[sock]
		_sockdex[get_socket_true_coord(coord)] = sock
		sock._position = get_socket_position_from_coord(coord)
	size = size.snappedf(G.snap * 2)
	_grid.x = floori(size.x / G.snap)
	_grid.y = floori(size.y / G.snap)

#region Drawing Background
func _draw() -> void:
	for p : int in panels:
		var rect = panelrect[p]
		var style = panelstyle[panels[p]]
		var pos_floor = rect.position.floor()
		var siz_floor = rect.size.abs().floor()
		var pos_deci = rect.position - pos_floor
		var siz_deci = (rect.size.abs() - siz_floor) * rect.size.sign()
		siz_floor *=  rect.size.sign()
		
		# Scale to the grid
		rect.position = pos_floor * G.snap + G.snap * pos_deci
		rect.size = siz_floor * G.snap + G.snap * siz_deci
		
		rect.position.x = clamp(rect.position.x, -G.snap, size.x)
		rect.position.y = clamp(rect.position.y, -G.snap, size.y)
		
		# Expand with node size.
		var max_end = size + Vector2(2,2) * G.snap
		rect.end.x = wrap(rect.end.x, rect.position.x + G.snap, max_end.x)
		rect.end.y = wrap(rect.end.y, rect.position.y + G.snap, max_end.y)
		
		draw_style_box(style, rect)
	
	# Visual helper to tell the grid cells
	if OS.has_feature("editor_hint") and show_grid:
		for y : int in range(_grid.y + 1):
			for x : int in range(_grid.x + 1):
				if y % 2 == 0 and x % 2 == 0: continue
				@warning_ignore("integer_division")
				var pos = G.from_grid(Vector2i(x / 2, y))
				draw_circle(pos, G.joint_rad, Color.HOT_PINK, false)
	
	for sock : ChartSocket in sockets:
		sock.draw(self)

#endregion

#region Socket Managment
# Get the grid coord of socket, after computing negative values
func get_socket_true_coord(socket_coord:Vector2i):
	@warning_ignore("integer_division")
	socket_coord.x = wrapi(socket_coord.x, 0, _grid.x / 2 + 1)
	@warning_ignore("integer_division")
	socket_coord.y = wrapi(socket_coord.y, 0, _grid.y / 2 + 1)
	return socket_coord
## Get a socket position from its Grid Coordinate, negative values wrap around to stay contained in the Gizmo.
func get_socket_position_from_coord(socket_coord:Vector2i) -> Vector2:
	return G.from_grid(get_socket_true_coord(socket_coord))
## Get a socket position from its instance
func get_socket_position(socket:ChartSocket) -> Vector2:
	var coord = sockets[socket]
	return get_socket_position_from_coord(coord)


func add_socket(_socket : ChartSocket, _coord := Vector2i.ZERO):
	pass
	#socket.coord = coord
	#sockets.append(socket)
	#register_socket(socket)
	#queue_sort()

func rem_socket(_socket : ChartSocket):
	pass
	#if owner is Flowchart:
		#owner.clear_wires(socket)
		#owner.graph.rem_socket(socket)
	#_sockdex.erase(get_socket_true_coord(socket))
	#sockets.erase(socket)
	#queue_sort()
#endregion

#region Input Events
var _mouse_hover : bool
func _init() -> void:
	resized.connect(_on_resized)
	mouse_entered.connect(func():_mouse_hover = true)
	mouse_exited.connect(_on_mouse_exit)
	_on_resized()

func _on_mouse_exit():
	_mouse_hover = false
	if hover_socket != null:
		hover_socket.pressed=false
		hover_socket.hover=false
		hover_socket = null
		queue_redraw()

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
	var cell = G.to_grid(get_local_mouse_position()).coord
	var sock = _sockdex.get(cell)
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
		"gizmo":self,
		"socket": socket,
		"local_position": get_socket_position(socket),
		"global_position": get_socket_position(socket) + position,
		}
	if sock_data.socket != null:
		owner.start_socket_wiring(sock_data)
func _on_socket_released(socket:ChartSocket):
	var sock_data = {
		"gizmo":self,
		"socket": socket,
		"local_position": get_socket_position(socket),
		"global_position": get_socket_position(socket) + position,
		}
	if sock_data.socket != null:
		owner.stop_socket_wiring(sock_data)

#endregion

#region Simulation Override Functions
@warning_ignore_start("unused_parameter")
func update(graph:FlowchartNetwork):
	_update(graph)
	update_done.emit()

func cycle_begin():
	_cycle_begin()
	begin_done.emit()

func cycle_finish():
	_cycle_finish()
	finish_done.emit()


func _update(graph:FlowchartNetwork):
	pass

func _cycle_begin():
	pass

func _cycle_finish():
	pass
#endregion
