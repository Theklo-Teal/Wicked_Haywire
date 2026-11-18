@tool
extends FlowchartPanel
class_name FlowchartGizmo

## A FlowchartPanel that carries and handles GizmoSockets, allowing them emit and 
## receive signals in the simulation system.[br]
## Sockets are grouped by sharing [code]GizmoCluster[/code] which have their own
## coordinate.[br]
## Changing layout means changing the coordinate of panels and clusters.
## Socket positioning will be relative to that surface's coordinate on the grid. [br]
##NOTE To have sockets that hang halfway over the edge, we have to do a visual trick.
## Actually doing this would make it hard to mouse over sockets at the edge, so instead
## we have an undersized panel shape (by 0.5) and then we can still have sockets totally
## enclose the Gizmo area while it looks like they hang off.

#region System Theory Complications
@export var delay : int = 0 :  ## How many jiffies it takes after input is read, for outputs to respond by writing to their ports.
	set(val):
		delay = max(0, val)
@export var dwell : int = 0 :  ## After the last sampling due [code]delay[/code] how many jiffies before it can sample again?
	set(val):
		dwell = max(0, val)
#NOTE: The terminology of "stock", "inflow" and "outflow" refers to processes with memory from System Theory.
var _stocks : Dictionary[int, Array]  # Values read from sockets, stored as `_Query` instances, that are being delayed.
var _queries : Dictionary[GizmoSocket, int]  # When was a socket last sampled? Given a `dwell` period, this might inhibit further inflow.

class _Query:
	var value  # A value read from a socket that's waiting in a stock.
	var created : int  # The global jiffy count when the query was created

	func _init(jiffies:int, socket_value) -> void:
		value = socket_value
		created = jiffies

## Samples a value from a socket using the given method of the socket. Calling this function
## instead of calling the method on the socket directly, using this function allows
## delay mechanisms to act.
func inflow(socket:GizmoSocket, method:StringName, ...args):
	if owner.jiffies - _queries.get(socket, 0) < dwell: return  # Inhibit sampling if already sampled within dwell time.
	var query_id = hash(socket) ^ hash(method)
	var fifo = _stocks.get_or_add(query_id, [])
	var query = _Query.new(owner.jiffies, socket.callv(method, args))
	fifo.append(query)
	_queries[socket] = owner.jiffies

## Retrieve the value of a socket which duration has surpassed delay. If no input is
## available, you may provide a default response.
func outflow(socket:GizmoSocket, method:StringName, default:=0):
	var query_id = hash(socket) ^ hash(method)
	var fifo : Array = _stocks.get(query_id, [])
	if fifo.is_empty(): return default
	var i : int = -1
	for query in fifo:
		i += 1
		var delta = owner.jiffies - query.created
		if delta == delay: break  #NOTE we discard queries that are too old, otherwise we might get into a situation of ever growing stocks among other problems.
	fifo = fifo.slice(i - 1)
	if fifo.is_empty(): return default
	return fifo[0].value
#endregion

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
		if socket_tooltip != null:
			socket_tooltip.hide()
			socket_tooltip.mouse_exited.connect(func(): socket_tooltip.hide())
			add_child(socket_tooltip, false, Node.INTERNAL_MODE_FRONT)

var socket_menu : PopupMenu :
	set(val):
		if socket_menu != null: 
			socket_menu.queue_free()
		socket_menu = val
		if socket_menu != null:
			socket_menu.hide()
			add_child(val, false, Node.INTERNAL_MODE_FRONT)

func _init() -> void:
	super()
	mouse_exited.connect(_on_mouse_exit)
	
	#await ready
	#socket_tooltip = preload("uid://cxgvler3bpjqk").instantiate()
	socket_menu = PopupMenu.new()

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
	if owner is Flowchart: _hover_input(event)
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
					socket_menu_visible(true, hover_socket)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				queue_redraw()
				if event.is_pressed():
					hover_socket.mouse_press()
					_on_socket_pressed(hover_socket)
				else:
					hover_socket.mouse_release()
					_on_socket_released(hover_socket)

@warning_ignore("unused_parameter")
## Called if the [code]owner[/code] is Flowchart and the mouse is over the Gizmo.
func _hover_input(event:InputEvent):
	pass

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

func local_socket_coord(sock:GizmoSocket=null) -> Vector2i:
	if sock == null: sock = hover_socket
	if not sock in sockets: return Vector2i.ZERO
	var cluster = sockets[sock]
	return cluster.transform_coord(sock.coord, get_bound_coord)

func local_socket_position(sock:GizmoSocket=null) -> Vector2:
	return Flowchart.from_grid(Vector2(local_socket_coord(sock)))

func canvas_socket_coord(sock:GizmoSocket=null) -> Vector2i:
	return local_socket_coord(sock) + _grid.position

func canvas_socket_position(sock:GizmoSocket=null) -> Vector2:
	return local_socket_position(sock) + position

func global_socket_position(sock:GizmoSocket=null) -> Vector2:
	if owner is Flowchart:
		return owner.to_screen_coord(canvas_socket_position(sock)) + owner.global_position
	if owner != null:
		return canvas_socket_position(sock) + owner.global_position
	return canvas_socket_position(sock)

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
			socket_tooltip.position = sock.position
			socket_tooltip.get_node("%Body").text = str(sock.port)
			socket_tooltip.get_node("%Show_State").button_pressed = sock.pressed
		else:
			socket_tooltip.hide()

func socket_menu_visible(shown:bool, sock:GizmoSocket=null):
	if owner is Flowchart and socket_menu != null:
		if shown:
			socket_menu.clear(true)
			if sock is BitInput:
				socket_menu.add_radio_check_item("No State Bias")
				socket_menu.add_radio_check_item("Biased Low")
				socket_menu.add_radio_check_item("Biased High")
			elif sock is BitOutput:
				socket_menu.add_check_item("Show Value")
				socket_menu.add_check_item("Invert Value")
			socket_menu.popup(Rect2(global_socket_position(sock), Vector2.ZERO))
		else:
			socket_menu.hide()
#endregion
