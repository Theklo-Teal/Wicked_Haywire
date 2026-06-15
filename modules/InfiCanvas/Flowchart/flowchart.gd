@tool
extends InfiCanvas
class_name Flowchart

## An Infinite Canvas were you can place panels with sockets, called "graph nodes".
## Their sockets can be connected together to form flowchart visualizations which 
## can process some operations or simulations for interactive and dynamic behaviours 
## between graph nodes. The data about the relationships between graph nodes is 
## stored in a FlowchartGraph resource. [br]
## This is very similar to Godot's GraphEdit node, but being a custom implementation,
## we can make it display things or operate on things in our custom way and without 
## being afraid of the "Experimental" tag.[br][br]
## Graphs can be extended to have different sets of Link types, which extend the
## generic "Link" inner class.[br]
## Different Links carry different formats of data and can behave differently when
## written or read to.[br]
## Each Link mentions the UID of FlowchartWire, so different types of signals can
## be represented with different colors or thickness, for example.[br]
## The generic Wire can vary in color or thickness. You can create several ".tres"
## resource files for varieties on those properties, or you can make scripts
## extending FlowchartWire to include more properties and behaviors. The UID in
## each Link doesn't mind if it's a resource file or the script of a Wire class.[br]
## The ChartSockets can extended to use different Link types, thus deciding
## What kind of wire they produce and which other sockets they are allowed to
## connect to.[br]
## Finally, graph nodes, or class FlowchartNode derivations contain Sockets as
## child nodes that automatically position to respect a snapping grid. Just don't
## forget to register them in the [code]FlowchartNode.sockets[/code] dictionary.[br]
## You are meant to be at the root of a scene and extended to define the behavior
## of their sockets. The can read or write to Links during the update part of the
## simulation cycle. The typical idea is to read from ChartSocketSink nodes, transform the
## value to something meaningful and write with ChartSocketSource nodes.[br]
## These classes of these sockets can be extended for different kinds of signals
## or protocols, thus different Links, thus different Wires.

#TODO Allow Rotating and Mirroring Graph Nodes
#TODO Procedural Nodes
#TODO Implement new Rect2 based wire method
#TODO Check if I can actually save the graph and reload it.
#TODO Allow Copy, Paste and Duplicate
#TODO Allow Undo/Redo: Class UndoRedo


const HIGHLIGHT_THICK = 3

@export var update_rate : float = 0.01 : 
	set(val):
		update_rate = max(0, val)
		if is_node_ready():
			$Update_Timer.wait_time = update_rate
@export var graph : FlowchartGraph : 
	set(val):
		if val == null:
			graph = FlowchartGraph.new()
		

#region Boilerplate

# Wire info
var wire_data : Dictionary  # [path] : Array[Vector2], [socket] : Dictionary, [branch] : Array[Vertex]
var wire_updated : bool = true
var select_wire : Array
var wiring_allowed : bool = true
var is_wiring : bool = false
var wire_shape : int = 0
var wires : Array[Array] ## Multidimantional Array as: [wire_shape][wire_alternative] -> FlowchartWire
@onready var wire_buttons := ButtonGroup.new()

enum Mode{
	EDITING,  ## Nodes being repositioned and sockets being connected.
	SIMULAT,  ## Node children being interacted with and their state affected manually.
	PLACING,  ## Adding a node to the Canvas #TODO Actualy implement this.
}
var mode : Mode : 
	set(val):
		mode = val
		G._on_flowchart_mode_changed(mode)
		for each in graph.nodes:
			each._on_flowchart_mode_changed(mode)

func _ready() -> void:
	for each in %wire_shapes.get_children():
		if each is Button:
			each.button_group = wire_buttons
	wire_buttons.pressed.connect((func(): if is_wiring: queue_redraw()).unbind(1))
	
	%zoom.pressed.connect(_on_zoom_pressed)
	%origin.pressed.connect(_on_origin_pressed)
	%zoom.text = str(roundi(zoom * 100)) + " %"
	%LineEdit.text_submitted.connect(_on_line_edit_submit)
	$PopupMenu.index_pressed.connect(_on_popup_pressed)
	$Update_Timer.timeout.connect(_on_update_timer_timeout)
	if not OS.has_feature("editor_hint"):
		$Update_Timer.start(update_rate)

#endregion

#region Drawing

func draw_fore_geometry(viewed_canvas_rect:Rect2):
	#for node : FlowchartNode in find_objects(viewed_canvas_rect, "graph_node"):
		#for socket : ChartSocket in node.sockets:
			#for wired_to : ChartSocket in socket.wires:
				#var wire : FlowchartWire = socket.wires[wired_to]
				#var wire_thick = wire.get_thick(socket, graph)
				#var wire_color = wire.get_color(socket, graph)
				#var from = to_screen_coord(graph.get_socket_position(socket))
				#var to = to_screen_coord(graph.get_socket_position(wired_to))
				#var verts = wire.get_vertices(from, to, Vector2(0.5, 0.5) * G.grid_size * zoom)
				#if verts.size() > 1:
					#draw_polyline(verts, wire_color, wire_thick * zoom)
	
	#region Draw established wires
	# TODO Sanitize wire vertices.
	if wire_updated:
		wire_updated = false
		#var removal : Array[FlowchartGraph.Vertex]
		#for v:FlowchartGraph.Vertex in parti.wire.obj_intel.keys():
			#pass
		#parti.wire.remove_objects(removal)
	
	
	for s in get_wire_segments(viewed_canvas_rect):
		var start = to_screen_coord(s[0].position)
		var stop = to_screen_coord(s[1].position)
		draw_line(start, stop, Color.WHITE, 4 )
	
	for s in select_wire:
		var start = to_screen_coord(s[0].position)
		var stop = to_screen_coord(s[1].position)
		draw_line(start, stop, Color.BURLYWOOD, 4 )
	
	for v in parti.wire.find_objects_simple(viewed_canvas_rect):
		draw_circle(to_screen_coord(v.position), 6, Color.WHITE)
	#endregion
	
	# Draw wire being pulled.
	if is_wiring and wiring_allowed:
		var from = to_screen_coord(wire_data.start)
		var to = get_local_mouse_position()
		var end_corner = to - from
		var bend_side = end_corner.abs().max_axis_index()  # This tells the chirality of the bend.
		if Input.is_key_pressed(KEY_SHIFT):
			bend_side = [1,0][bend_side]
		var middle
		if bend_side == 0:  # Long segment is horizontal
			middle = Vector2(to.x, from.y)
		else:  # Long segment is vertical
			middle = Vector2(from.x, to.y)
		draw_line(from, middle, Color.WHITE, 5)
		var rect = (to - from).abs()
		if not (rect.y < G.grid_size or rect.x < G.grid_size):
			draw_line(middle,to, Color.WHITE, 5)
			wire_data["bend"] = to_canvas_coord(middle)

#endregion

#region Input Handling
func _gui_input(event: InputEvent) -> void:
	super(event)
	
	if event is InputEventMouseButton:
		if event.is_pressed():
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					move_obj_allowed = false
					if not is_moving_obj:
						_selected.clear()
					if wiring_allowed:
						if is_wiring:
							pass
						else:
							if mode == Mode.EDITING and G.grabbed_buttons.get_pressed_button() == null:
								#TODO mode == Mode.EDITING, in contrast to mode == Mode.PLACING instead of checking `grabbed_buttons`
								start_canvas_wiring(to_canvas_coord(event.position))
		elif event.is_released():
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					if is_wiring and wiring_allowed:
						stop_canvas_wiring(to_canvas_coord(event.position))
					elif lasso_canvas_rect.size > MINIMUM_LASSO:
						if lasso_allowed:
							if lasso_mode:
								_selected += parti.node.find_objects_tolerant(lasso_canvas_rect)
								if Input.is_key_pressed(KEY_SHIFT):
									pass
							else:
								_selected += parti.node.find_objects_zealous(lasso_canvas_rect)
								if Input.is_key_pressed(KEY_SHIFT):
									pass
				
				MOUSE_BUTTON_RIGHT:
					$PopupMenu.popup(Rect2(event.global_position, Vector2.ZERO))

func _input(event: InputEvent) -> void:
	super(event)
	
	if event is InputEventKey and not event.is_echo():
		if event.keycode == KEY_DELETE:
			for each in _selected:
				if each is FlowchartNode:
					remove_graph_node(each)
		if event.keycode == KEY_SHIFT:
			if is_wiring:
				queue_redraw()
			if event.is_pressed() and is_moving_obj:
				# Regretting not having held Shift before mouse motion.
				pass
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_released():
				move_obj_allowed = true
				selected_obj_movement_stop()
	
	if event is InputEventMouseMotion:
		if is_wiring and wiring_allowed:
			queue_redraw()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_moving_obj and move_obj_allowed:
			selected_obj_movement_start()
		if is_moving_obj and move_obj_allowed:
			if not Input.is_key_pressed(KEY_SHIFT):
				pass

func escape_key_action():
	if is_wiring:
		exit_wiring()
		return
	super()

func set_selected(val:Array):
	super(val)
	%LineEdit.hide()


func _on_line_edit_submit(_txt:String):
	match %LineEdit.placeholder_text:
		"Tunnel Name":
			pass
		"Node Name":
			pass

func set_zoom(val:float):
	super(val)
	if not is_node_ready():
		await ready
	%zoom.text = str(roundi(zoom * 100)) + " %"

func _on_zoom_pressed():
	zoom = 1
	%zoom.text = "100 %"

func _on_origin_pressed():
	go_to(Vector2.ZERO)

#endregion

#region Add or Remove objects

func _on_popup_pressed(idx:int):
	match $PopupMenu.get_item_text(idx):
		"Info Panel":
			var node = load("res://modules/InfiCanvas/Flowchart/Nodes/info_panel.tscn").instantiate()
			add_graph_node(node, to_canvas_coord(fin_mouse))
		"Ammeter":
			pass
		"Voltmeter":
			pass
		"Cabling":
			var node = load("res://modules/InfiCanvas/Flowchart/Nodes/info_panel.tscn").instantiate()
			add_graph_node(node, to_canvas_coord(fin_mouse))
		"Tri-State Buffer":
			pass


#region Nodes
func add_graph_node(res:String, where:=Vector2.ZERO):
	queue_redraw()
	var node = load(res)
	if node is Script:
		node = node.new()
	elif node is PackedScene:
		node = node.instantiate()
	else:
		return null
	place_object(node, where, parti.node)
	node.position = to_canvas_coord(fin_mouse)
	node._on_flowchart_mode_changed(mode)
	graph.add_node(node)
	return node

func remove_graph_node(node:FlowchartNode):
	graph.rem_node(node)
	#TODO Remove node sockets from links.
	await graph.sim_cycle_begun
	queue_redraw()
	remove_object(node)
	node.queue_free()
#endregion

#region Wires
func enter_wiring() -> Error:
	if not is_wiring and wiring_allowed:
		is_wiring = true
		is_moving_obj = false
		move_obj_allowed = false
		lasso_allowed = false
		return OK
	return FAILED

func exit_wiring() -> Error:
	if is_wiring and wiring_allowed:
		queue_redraw()
		is_wiring = false
		move_obj_allowed = true
		lasso_allowed = true
		wire_data.clear.call_deferred()
		return OK
	return FAILED

func start_socket_wiring(socket_data:Dictionary):
	if enter_wiring() == OK:
		wire_data["socket"] = socket_data
		wire_data["path"] = [socket_data.canvas_coord]

func stop_socket_wiring(socket_data:Dictionary):
	if socket_data.node != wire_data.socket.node:
		if exit_wiring() == OK:
			# Store in the Graph
			wire_data["socket"] = socket_data
			wire_data["path"].append(socket_data.canvas_coord)

## Detect if a wire was clicked and make a branch of it.
func start_canvas_wiring(where:Vector2):
	var MARGIN = 4  # How much space around the wire does it still count as having clicked on the wire.
	select_wire.clear()
	
	# Search relevant vertices.
	var rect = Rect2(where - Vector2.ONE * MARGIN, Vector2(2,2) * MARGIN)
	var verts = parti.wire.find_objects(rect)
	
	# Test segments against the mouse position
	var checked : Dictionary[FlowchartGraph.Vertex, Array]
	for v0 : FlowchartGraph.Vertex in verts:
		checked[v0] = []
		var c = v0.get_segments()
		for v1 in c.horiz:
			if v0 in checked.get(v1, []):
				continue
			checked[v0].append(v1)
			var span = [v0.position.x, v1.position.x]
			if where.x > span.min() and where.x < span.max():
				if abs(where.y - v0.position.y) < MARGIN:
					select_wire.append([v0, v1])
		for v1 in c.verti:
			if v0 in checked.get(v1, []):
				continue
			checked[v0].append(v1)
			var span = [v0.position.y, v1.position.y]
			if where.y > span.min() and where.y < span.max():
				if abs(where.x - v0.position.x) < MARGIN:
					select_wire.append([v0, v1])
	
	# Branch Wire
	var s = select_wire.back()
	if s != null and enter_wiring() == OK:
		wire_data["path"] = [where]
		wire_data["branch"] = s

## A wire was stopped in the middle of the canvas instead of on a socket.
func stop_canvas_wiring(_where:Vector2):
	if exit_wiring() == OK:
		var verts : Array[FlowchartGraph.Vertex]
		var i : int = -1
		for coord in wire_data.path:
			i += 1
			verts[i] = FlowchartGraph.Vertex.new()
			parti.wire.add_object(verts[i], coord)
			verts[i].position = coord.snappedf(G.grid_size)
			
			if i > 0:
				verts[i].conn.append(verts[i-1])
				verts[i-1].conn.append(verts[i])
		if wire_data.has("branch"):
			verts[0].conn.append_array(wire_data["branch"])
		
		wire_updated = true
		
		#TODO Update the Graph

## Returns a list of Vertex pairs that are connected, within the given Rect2.
func get_wire_segments(canvas_rect:Rect2) -> Array:
	var segm : Array
	var checked : Dictionary[FlowchartGraph.Vertex, Array]
	for v in parti.wire.find_objects(canvas_rect):
		checked[v] = []
		for c in v.conn:
			if not c in checked or not v in checked[c]:
				checked[v].append(c)
				segm.append([v, c])
	return segm
#endregion

#endregion

#region Simulation Implementation
signal sim_cycle_started
signal sim_update_started
signal sim_update_finish
signal sim_cycle_finish

var in_a_cycle : bool = false
var skip_cycle : bool = false
var sim_paused : bool = false
var tick_elapse : float = 0
var process_elapse : float = 0

func pause_sim():
	#NOTE: we can't stop the timer because the Graph relies on it for removing or adding Graph Nodes.
	sim_paused = true
func resume_sim():
	sim_paused = false
func reset_sim():
	for link in graph.the_links:
		graph.the_links[link] = link.default

func _on_update_timer_timeout():
	if in_a_cycle:
		printerr("Simulation Rate not keeping up with cycle duration!")
		skip_cycle = true
	_on_sim_update()

func _on_sim_update():
	var begin_time := Time.get_ticks_usec()
	in_a_cycle = true
	sim_cycle_started.emit()
	
	graph.cycle_begin()
	
	if not (skip_cycle or sim_paused):
		for node in graph.nodes:
			node.cycle_begin()
		
		sim_update_started.emit()
		for node in graph.nodes:
			node.update(graph)
		sim_update_finish.emit()
	
		for node in graph.nodes:
			node.cycle_finish()
	
	graph.cycle_finish()
	
	sim_cycle_finish.emit()
	in_a_cycle = false
	tick_elapse = (Time.get_ticks_usec() - begin_time) / 1_000_000.0  # microseconds it took for all nodes to be done.
#endregion
