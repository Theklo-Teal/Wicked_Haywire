@tool
extends FlowchartSocket
class_name FlowchartSocketRelay

## This kind of socket behaves like a Graph Node and isn't intended to be part of one.[br]
## It is automatically placed at the vertices of wires, allowing them to be composited or edited.[br]

@export_range(1, 200, 1, "or_greater") var grid_size : int = 30 : 
	set(val):
		grid_size = val
		queue_redraw()

func _get_grid_size():
	if owner is Flowchart:
		return owner.snap_val
	else:
		print("not in Flowchart")
		return grid_size

@export var tunnel : StringName = "" :  ## vias with the same tunnel ID and that ID is not empty, count as connected even if no wire is drawn between them.
	set(val):
		queue_redraw()
		tunnel = val
		if owner is Flowchart:
			if val.is_empty():
				owner.graph.disconnect_socket(self, val)
			else:
				owner.graph.connect_socket(self, tunnel)

var show_link := false
var show_signal := false
var signal_value

func _parti_registered(data:Dictionary) -> void:
	size = Vector2.ONE * _get_grid_size()
	mouse_filter = Control.MOUSE_FILTER_STOP
	link_class = ""  # Relays shouldn't discriminate link classes.
	accepted_link = ["Link"]
	refuse_link.clear()
	data.registry_acknowledged = true

func _canvas_reposition(data:Dictionary):
	position = data.get("alt_position", data.position)

func _ready() -> void:
	color = Color.WHITE
	alt_color = Color.BLACK
	show_name = false
	
	menu.clear()
	menu.add_item("Delete")
	menu.add_check_item("Show Signal Value")
	
	button_down.connect(_on_pressed)
	button_up.connect(_on_released)
	pressed.connect(_on_click)


func _on_pressed():
	if owner is Flowchart:
		var existing = owner._selected.find(self)
		if Input.is_key_pressed(KEY_CTRL):
			if existing < 0:
				owner._selected += [self]
			else:
				owner._selected.remove_at(existing)
		else:
			owner.start_wiring(self)

func _on_released():
	if owner is Flowchart:
		owner.stop_wiring(self)

func _on_click(button:MouseButton):
	if button == MOUSE_BUTTON_RIGHT:
		if owner is Flowchart:
			owner._selected = [self]

func _on_menu_index_pressed(idx:int):
	var txt = menu.get_item_text(idx)
	match txt:
		"Delete":
			if owner is Flowchart:
				owner.remove_relay(self)
		"Show Signal Value":
			menu.toggle_item_checked(idx)
			show_signal = menu.is_item_checked(idx)

func _draw() -> void:
	var rad = min(size.x, size.y) / 2
	var center = Vector2.ONE * rad
	
	var color_1 : Color
	var color_2 : Color = color
	var color_3 : Color = alt_color
	if link != null and owner is Flowchart:
		color_1 = owner.get_wire_from_Link(link).color
		color_2 = color_2.lerp(color_1, 0.50)
		color_3 = color_3.lerp(color_1, 0.50)
	
	match get_wire_count():
		0:  # Lonely Relay
			draw_circle(center, rad, color)
		1:  # End point of a wire
			draw_circle(center, rad * 0.8, color_1)
		2: # Don't render anything unless it's a tunnel
			if not tunnel.is_empty():  # Is a tunnel
				draw_circle(center, rad * 0.8, color_1)
		_:
			draw_circle(center, rad * 0.8, color_2)
	
	if mouse_over:
		draw_circle(center, rad, color_3 , false, 4)
	if not tunnel.is_empty():
		draw_circle(center, rad * 0.4, alt_color)
	
	if not tunnel.is_empty():
		draw_label(tunnel)
	elif show_link:
		draw_label(str(hash(link)))
	elif show_signal:
		draw_label(str(signal_value)) 

## Find if this relay is really necessary according to wire geometry between adjacent sockets. Returns the list of adjacent sockets that are found to have a straight wire in between.
func check_retirement() -> Array[FlowchartSocket]:
	var ortho_sockets : Array[FlowchartSocket]
	if owner is Flowchart:
		var retire := true
		var adjacent = wires.keys() + seriw
		for A in adjacent:
			for B in adjacent:
				if A == B:
					continue
				var wire : FlowchartWire = wires.get(A, A.wires.get(self))
				var verts = wire.get_vertices(
					owner.graph.get_socket_position(A),
					owner.graph.get_socket_position(B),
					)
				if verts.size() > 2:
					retire = false
					break
				else:
					if not A in ortho_sockets:
						ortho_sockets.append(A)
					if not B in ortho_sockets:
						ortho_sockets.append(B)
			if retire == false:
				return []
		return ortho_sockets
	else:
		return []


func connecter(other_socket:FlowchartSocket, wire:FlowchartWire):
	super(other_socket, wire)
	queue_redraw()
func connectee(other_socket:FlowchartSocket, wire:FlowchartWire):
	super(other_socket, wire)
	queue_redraw()
func disconnecter(other_socket:FlowchartSocket):
	super(other_socket)
	queue_redraw()
func disconnectee(other_socket:FlowchartSocket):
	super(other_socket)
	queue_redraw()


func update(graph:FlowchartGraph):
	if link == null:
		# Delete itself
		pass
	else:  # Only redraw if there's a change in value.
		if graph.the_links[link] != signal_value:
			signal_value = graph.the_links[link]
			queue_redraw()
