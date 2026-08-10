@tool
extends FlowchartPanel
class_name FlowchartGizmo

## A FlowchartPanel that carries and handles GizmoSockets, allowing them emit and 
## receive signals in the simulation system.[br]
## Sockets are grouped by sharing [code]GizmoCluster[/code] which have their own
## coordinate.[br]
## Changing layout means changing the coordinate of . Socket positioning will
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
		sock.position = Flowchart.from_grid(coord)  # Position on the Gizmo


func _set_show_grid(val:bool):
	super(val)
	_update_sockdex()

var socket_tooltip : Control : 
	set(val):
		if socket_tooltip != null: socket_tooltip.queue_free()
		socket_tooltip = val
		socket_tooltip.hide()
		socket_tooltip.mouse_exited.connect(func(): socket_tooltip.hide())
		add_child(socket_tooltip, false, Node.INTERNAL_MODE_FRONT)

var socket_menu := PopupMenu.new()

func _init() -> void:
	super()
	mouse_exited.connect(_on_mouse_exit)
	
	#await ready
	#socket_tooltip = preload("uid://cxgvler3bpjqk").instantiate()


func _on_resized():
	super()
	_update_sockdex()

func _on_mouse_exit():
	_mouse_hover = false
	#if not Input.is_key_pressed(KEY_CTRL): socket_tooltip_visible(false)
	if hover_socket != null:
		hover_socket.hover=false
		hover_socket = null
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not _mouse_hover: return
	#if event is InputEventKey:
	#	if event.keycode == KEY_CTRL and event.is_released():
	#		socket_tooltip_visible(false)
	
	if not (owner is Flowchart and owner.mode == Flowchart.Mode.EDITING): return
	if event is InputEventMouseMotion:
		if _mouse_stopped:
			_mouse_stopped = false
			_on_mouse_started()
		_mouse_stopped_frames = 0
	
	if event is InputEventMouseButton:
		_on_mouse_stopped()  # Force testing if mouse is over a socket.
		if hover_socket != null:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if Input.is_key_pressed(KEY_CTRL) and event.is_pressed():
					#socket_menu_visible(true, hover_socket)
					pass
				else:
					var pos = canvas_socket_position(hover_socket)
					var sock_data = {
						"netvert": hover_socket,
						"coord": Flowchart.to_grid(pos),
						"canvas_position": pos,
						}
					if event.is_pressed():
						owner.start_socket_wiring(sock_data)
					elif event.is_released():
						owner.stop_socket_wiring(sock_data)
			
			elif event.button_index == MOUSE_BUTTON_LEFT:
				queue_redraw()
				if event.is_pressed():
					hover_socket.mouse_press()
					_on_socket_pressed(hover_socket)
				else:
					hover_socket.mouse_release()
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
	var cell := Flowchart.to_grid(get_local_mouse_position())
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
			#if not Input.is_key_pressed(KEY_CTRL): socket_tooltip_visible(false)
			hover_socket.hover = false
		
		if val != null:
			# Now hovering a socket.
			socket_tooltip_visible(true, val)
			val.hover = true
		
		hover_socket = val

#endregion


func _draw() -> void:
	super()
	for coord in _sockdex:
		var where = Flowchart.from_grid(coord)
		_sockdex[coord].draw(owner if owner is Flowchart else null, self, where)


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

func local_socket_position(sock:GizmoSocket) -> Vector2:
	return Flowchart.from_grid(Vector2(local_socket_coord(sock)))

func canvas_socket_coord(sock:GizmoSocket) -> Vector2i:
	return local_socket_coord(sock) + _grid.position

func canvas_socket_position(sock:GizmoSocket) -> Vector2:
	return sock.position + position

## Registering new sockets when dynamically adding them during simulation.
func add_socket(_socket : GizmoSocket):
	pass

## Unregistering new sockets when dynamically adding them during simulation.
func rem_socket(_socket : GizmoSocket):
	pass
	##if owner is Flowchart:
		##owner.clear_wires(socket)
		##owner.graph.rem_socket(socket)
	##_sockdex.erase(get_socket_true_coord(socket))
	##sockets.erase(socket)
	##queue_sort()

func socket_tooltip_visible(shown:bool, sock:GizmoSocket=null):
	if owner is Flowchart and socket_tooltip != null:
		if shown:
			socket_tooltip.show()
			socket_tooltip.position = sock.position + Vector2.ONE * Flowchart.SNAP
			socket_tooltip.get_node("%Body").text = str(sock.port)
			socket_tooltip.get_node("%Show_State").button_pressed = sock.pressed
		else:
			socket_tooltip.hide()

func socket_menu_visible(shown:bool, sock:GizmoSocket=null):
	if owner is Flowchart and socket_tooltip != null:
		if shown:
			socket_menu.popup(Rect2(sock.position, Vector2.ZERO))
		else:
			socket_menu.hide()
#endregion
