@tool
extends FlowchartPanel
class_name FlowchartGizmo

## A FlowchartPanel that carries and handles GizmoSockets, allowing them to partake
## in the simulation system.[br]
## Sockets are grouped into "clusters" which then are associated with a "surface".
## Changing layout means changing the surface associations. Socket positioning will
## be relative to that surface's coordinate on the grid.

@export var sockets : Dictionary[GizmoSocket, Cluster] :  ## GizmoSockets and the cluster they belong to.
	set(val):
		queue_redraw()
		sockets = val
		_update_sockdex()

var _sockdex : Dictionary[Vector2i, GizmoSocket]  # Back reference to find which socket is in at certain local grid coord. Coordinates are wrapped, so if they are negative in [code]sockets[/code] they will be positive here.
func _update_sockdex():
	queue_redraw()
	_sockdex.clear()
	for sock in sockets:
		var cluster = sockets[sock]
		var coord = get_bound_coord(sock.coord)
		if not sock.changed.is_connected(_update_sockdex):
			sock.changed.connect(_update_sockdex)
		if not cluster.changed.is_connected(_update_sockdex):
			cluster.changed.connect(_update_sockdex)
		coord = local_socket_coord(sock)
		_sockdex[coord] = sock
		sock.position = get_canvas_position(coord)  # Set the position to the socket that's relevant for canvas drawing.


func _set_show_grid(val:bool):
	super(val)
	_update_sockdex()

func _init() -> void:
	super()
	mouse_exited.connect(_on_mouse_exit)
	#
	#await ready
	##add_child(socket_tooltip, false, Node.INTERNAL_MODE_FRONT)
	##socket_tooltip.hide()
	##socket_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	##socket_tooltip.z_index = 4000
	##var tooltip = Label.new()
	##tooltip.name = "Label"
	##tooltip.text = "TOOLTIPPED"
	##tooltip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	##socket_tooltip.add_child(tooltip)
	##add_child(socket_menu, false, Node.INTERNAL_MODE_FRONT)
	##socket_menu.add_check_item("Show State")

func _on_resized():
	super()
	_update_sockdex()

func _on_mouse_exit():
	_mouse_hover = false
	if hover_socket != null:
		hover_socket.pressed=false
		hover_socket.hover=false
		hover_socket = null
		queue_redraw()

func _input(event: InputEvent) -> void:
	if _mouse_hover and G.chart.mode == Flowchart.Mode.EDITING:
		if event is InputEventMouseMotion:
			if _mouse_stopped:
				_mouse_stopped = false
				_on_mouse_started()
			_mouse_stopped_frames = 0
		if event is InputEventMouseButton and owner is Flowchart:
			if hover_socket != null:
				if event.button_index == MOUSE_BUTTON_RIGHT:
					if Input.is_key_pressed(KEY_CTRL):
						if event.is_pressed():
							#and owner.mode == Flowchart.Mode.EDITING
							# Show popup menu for hover_socket
							#var where = owner.to_screen_coord(position + get_socket_position(hover_socket))
							#socket_menu.popup(Rect2(where, Vector2.ZERO))
							pass
					else:
						var pos = canvas_socket_position(hover_socket)
						var sock_data = {
								"netvert": hover_socket,
								"coord": Flowchart.to_grid(pos),
								"canvas_position": pos,
								}
						if sock_data.netvert != null:
							if event.is_pressed(): owner.start_socket_wiring(sock_data)
							elif event.is_released(): owner.stop_socket_wiring(sock_data)
				elif event.button_index == MOUSE_BUTTON_LEFT:
					if event.is_pressed():
						hover_socket.pressed = true
						_on_socket_pressed(hover_socket)
					else:
						hover_socket.pressed = false
						_on_socket_released(hover_socket)


#region Detect When the Mouse is Over a Socket
const _MOUSE_MOVE_THRESHOLD = 6  # How many process frames have to pass to consider the mouse stopped?
var _mouse_stopped_frames : int  # How many frames the mouse hasn't moved.
var _mouse_stopped : bool = false
func _process(delta: float) -> void:
	super(delta)
	if _mouse_hover:
		# The _MOUSE_MOVE_THRESHOLD here acts a bit like an input debouncing mechanism.
		if _mouse_stopped_frames > _MOUSE_MOVE_THRESHOLD and not _mouse_stopped:
			_mouse_stopped = true
			_on_mouse_stopped()
		else:
			_mouse_stopped_frames = _mouse_stopped_frames + 1
			# Keep number above threshold if it wraps around the larges possible int.
			if _mouse_stopped_frames < 0: _mouse_stopped_frames = _MOUSE_MOVE_THRESHOLD

func _on_mouse_stopped():
	# Check if mouse is over a socket.
	var cell := Flowchart.to_grid(get_local_mouse_position(), true)
	var sock = _sockdex.get(cell, null)
	hover_socket = sock

func _on_mouse_started():
	pass

var hover_socket : GizmoSocket : 
	set(val):
		if val == hover_socket: return # Only care if value actually changed
		queue_redraw() 
		
		if hover_socket != null:
			# Was previously on a socket
			#socket_tooltip.hide()
			hover_socket.hover = false
		
		if val != null:
			# Now hovering a socket.
			#show_socket_tooltip(val)
			val.hover = true
		
		hover_socket = val

#endregion


func _draw() -> void:
	super()
	if not owner is Flowchart:
		# Autonomous drawing of sockets if outside a Flowchart
		for coord in _sockdex:
			var where = Flowchart.from_grid(coord, true)
			_sockdex[coord].draw(null, self, where)


#region Socket Managment
@warning_ignore("unused_parameter")
func _on_socket_pressed(socket:GizmoSocket):
	pass
@warning_ignore("unused_parameter")
func _on_socket_released(socket:GizmoSocket):
	pass

func local_socket_coord(sock:GizmoSocket) -> Vector2i:
	var cluster = sockets[sock]
	return cluster.transform_coord(sock.coord, get_bound_coord)

func canvas_socket_coord(sock:GizmoSocket) -> Vector2i:
	return local_socket_coord(sock) + _grid.position

func canvas_socket_position(sock:GizmoSocket) -> Vector2:
	return sock.position + position


func add_socket(_socket : GizmoSocket):
	pass

func rem_socket(_socket : GizmoSocket):
	pass
	##if owner is Flowchart:
		##owner.clear_wires(socket)
		##owner.graph.rem_socket(socket)
	##_sockdex.erase(get_socket_true_coord(socket))
	##sockets.erase(socket)
	##queue_sort()
#
##func show_socket_tooltip(sock:GizmoSocket):
	##socket_tooltip.show()
	##socket_tooltip.position = sock.position + Vector2(16, 16)
	##socket_tooltip.get_node("Label").text = str(sock.port)
#endregion
