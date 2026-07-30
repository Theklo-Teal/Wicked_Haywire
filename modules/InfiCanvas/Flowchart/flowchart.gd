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
## Networks can be extended to have different sets of Link types, which extend the
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
## Finally, graph nodes, or class FlowchartGizmo derivations contain Sockets as
## child nodes that automatically position to respect a snapping grid. Just don't
## forget to register them in the [code]FlowchartGizmo.sockets[/code] dictionary.[br]
## You are meant to be at the root of a scene and extended to define the behavior
## of their sockets. The can read or write to Links during the update part of the
## simulation cycle. The typical idea is to read from ChartSocketSink nodes, transform the
## value to something meaningful and write with ChartSocketSource nodes.[br]
## These classes of these sockets can be extended for different kinds of signals
## or protocols, thus different Links, thus different Wires.

#TODO Allow Rotating and Mirroring Graph Nodes
#TODO Procedural Nodes
#TODO Implement new Rect2 based wire method
#TODO Check if I can actually save the network and reload it.
#TODO Allow Copy, Paste and Duplicate
#TODO Allow Undo/Redo: Class UndoRedo


const HIGHLIGHT_THICK = 3

@export var update_rate : float = 0.01 :  # Time for the simulation to update state.
	set(val):
		update_rate = max(0, val)
		if is_node_ready():
			$Update_Timer.wait_time = update_rate
@export var trace_color_primary := Color.GOLDENROD
@export var trace_color_secondary := Color.GOLD
@export var trace_color_highlight := Color.YELLOW

func _on_appearance_changed():
	cell_size = G.appearance.cell_size
	color = G.appearance.color
	orig_color = G.appearance.orig_color
	grid_color = G.appearance.grid_color
	grid_thick = G.appearance.grid_thick
	orig_thick = G.appearance.orig_thick
	trace_color_primary = G.appearance.trace_primary
	trace_color_secondary = G.appearance.trace_secondary
	trace_color_highlight = G.appearance.trace_highlight

#region Grid Snapping
@export var snap : int = 12 :  ## Size of grid snapping cells. The snap grid is based on a rhombus. Refer to [code]Flowchart.to_grid()[/code] for more information.
	set(val):
		G.snap = val
		snap = G.snap
@export var via_hole : int = 4 :  ## Radius of the holes in joints.
	set(val):
		G.via_hole = val
		via_hole = G.via_hole
@export var max_wire : int = 8 :  ## Maximum thickness of a wire.
	set(val):
		G.max_wire = val
		max_wire = G.max_wire
@export var clearance : int = 2 :  ## Minimum distance between conductors.
	set(val):
		G.clearance = val
		clearance = G.clearance

var joint_rad : float

## Returns the actual space position snapped to the grid from a grid coordinate.
func from_grid(coord:Vector2i) -> Vector2:
	return Vector2(coord) * snap

## Returns [code]coord[/code]
func to_grid(position:Vector2) -> Vector2i:
	var coord := Vector2i(  ## Find cell coordinate in the grid
		roundi(inverse_lerp(0, snap * 2, position.x)),
		roundi(inverse_lerp(0, snap, position.y))
		)
	return coord
#endregion

func _process(delta: float) -> void:
	if OS.has_feature("editor_hint"): return
	process_elapse += delta
	if process_elapse > update_rate:
		process_elapse = 0.0
		if in_a_cycle:
			printerr("Flowchart: Simulation Rate not keeping up with cycle duration!")
	_on_sim_update()
	skip_cycle = false


#region Boilerplate
var gizmo_pallet : Dictionary[String, Resource]

enum Mode{
	EDITING,  ## Nodes being repositioned and sockets being connected.
	SIMULAT,  ## Node children being interacted with and their state affected manually.
}
var mode : Mode : 
	set(val):
		mode = val
		G._on_flowchart_mode_changed(mode)
		for gizmo : FlowchartGizmo in Net.netlist.gizmos.get(G.layer, []):
			gizmo._on_flowchart_mode_changed(mode)

func _ready() -> void:
	G.chart = self
	for gizmo_file in DirAccess.get_files_at("res://gizmos/"):
		if not gizmo_file.get_extension() in ["gd", "tscn"]: continue
		gizmo_pallet[gizmo_file.get_basename()] = load("res://gizmos/" + gizmo_file)
	
	%zoom.pressed.connect(_on_zoom_pressed)
	%origin.pressed.connect(_on_origin_pressed)
	%zoom.text = str(roundi(zoom * 100)) + " %"
	%LineEdit.text_submitted.connect(_on_line_edit_submit)
	$PopupMenu.index_pressed.connect(_on_popup_pressed)
#endregion

#region Drawing

func draw_back_geometry(viewed_canvas_rect:Rect2):
	if OS.has_feature("editor_hint"): return

func draw_fore_geometry(canvas:Control, viewed_canvas_rect:Rect2):
	if OS.has_feature("editor_hint"): return
	
	for joint in parti.joint.find_objects_simple(viewed_canvas_rect):
		if joint is FlowchartSocket:
			joint.draw(self)
	
	# Draw wire being pulled.
	if wiring_allowed and not G.wire_from.is_empty():
		NetBase.Link.draw_length(canvas, to_screen_coord(G.wire_from.global_position), get_local_mouse_position(), Input.is_key_pressed(KEY_SHIFT), G.snap)
	
	for gizmo in Net.netlist.gizmos.get_or_add(G.layer, []):
		for sock in gizmo.sockets:
			sock.draw(self)

func draw_overlay(canvas:Control, _viewed_canvas_rect:Rect2):
	if OS.has_feature("editor_hint"): return
	
	var where = G.snap_grid(get_local_mouse_position())
	var clr = G.appearance.color.inverted()
	clr.a = 0.4
	canvas.draw_circle(where, G.joint_rad, clr)

#endregion

#region Input Handling
func _gui_input(event: InputEvent) -> void:
	super(event)
	
	if event is InputEventMouseButton:
		var cell = G.to_grid(to_canvas_coord(event.position))
		if event.is_pressed():
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					move_obj_allowed = false
					if not is_moving_obj:
						_selected.clear()
					if wiring_allowed:
						var via = Net.netlist.joints.get(Vector3i(cell.x, cell.y, G.layer), null)
						if via != null:
							start_via_wiring({
								"socket": via,
								"local_position": event.position,
								})
						elif not G.wire_from.is_empty():
							stop_canvas_wiring(event.position)
		elif event.is_released():
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					if wiring_allowed and not G.wire_from.is_empty():
						stop_canvas_wiring(event.position)
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
					#$PopupMenu.popup(Rect2(event.global_position, Vector2.ZERO))
					add_gizmo("bogus", to_canvas_coord(event.position))

func _input(event: InputEvent) -> void:
	super(event)
	
	if event is InputEventKey and not event.is_echo():
		if event.keycode == KEY_DELETE:
			for each in _selected:
				if each is FlowchartGizmo:
					rem_gizmo(each)
		if event.keycode == KEY_SHIFT:
			if not G.wire_from.is_empty():
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
		if wiring_allowed and not G.wire_from.is_empty():
			queue_redraw()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_moving_obj and move_obj_allowed:
			selected_obj_movement_start()
		if is_moving_obj and move_obj_allowed:
			if not Input.is_key_pressed(KEY_SHIFT):
				pass

func obj_movement_modulate(new_position:Vector2) -> Vector2:
	return G.snap_grid(new_position)

func escape_key_action():
	if not G.wire_from.is_empty():
		G.wire_from.clear()
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
			add_gizmo(node, to_canvas_coord(fin_mouse))
		"Ammeter":
			pass
		"Voltmeter":
			pass
		"Cabling":
			var node = load("res://modules/InfiCanvas/Flowchart/Nodes/info_panel.tscn").instantiate()
			add_gizmo(node, to_canvas_coord(fin_mouse))
		"Tri-State Buffer":
			pass


#region Nodes
func add_gizmo(res:String, where:=Vector2.ZERO) -> FlowchartGizmo:
	var gizmo = gizmo_pallet.get(res)
	if gizmo is Script:
		gizmo = gizmo.new()
	elif gizmo is PackedScene:
		gizmo = gizmo.instantiate()
	where = G.snap_grid(where)
	place_object(gizmo, where, parti.node)
	Net.register_gizmo(gizmo, G.layer)
	gizmo._on_flowchart_mode_changed(mode)
	return gizmo

func rem_gizmo(_gizmo:FlowchartGizmo):
	pass
	#net.rem_node(node)
	##TODO Remove node sockets from links.
	#await net.sim_cycle_begun
	#queue_redraw()
	#remove_object(node)
	#node.queue_free()

func add_via(where:Vector2) -> NetBase.Via:
	var via = Net.get_or_add_joint(to_canvas_coord(where), G.layer, Net.Via.new())
	place_object(via, via.position, parti.joint)
	queue_redraw()
	return via

func rem_via(via:NetBase.Via):
	remove_object(via)
	queue_redraw()

#endregion

#region Wires

#endregion

#endregion

#region Wiring
# Wire info
var wiring_allowed : bool = true

## Gizmo socket has started a wire.
func start_socket_wiring(sock_data:Dictionary):
	lasso_allowed = false
	G.wire_from = sock_data

## Wire stopped at a Gizmo socket.
func stop_socket_wiring(sock_data:Dictionary):
	sock_data.socket.connected[G.wire_from.socket] = null
	G.wire_from.socket.connected[sock_data.socket] = NetBase.Link.new()
	G.wire_from.socket.connected[sock_data.socket].chirality = Input.is_key_pressed(KEY_SHIFT)
	
	lasso_allowed = true
	G.wire_from.clear()
	queue_redraw()

## Wire stopped on empty canvas.
func stop_canvas_wiring(where:Vector2):
	var via : NetBase.Via = add_via(where)
	via.connected[G.wire_from.socket] = null
	G.wire_from.socket.connected[via] = NetBase.Link.new()
	G.wire_from.socket.connected[via].chirality = Input.is_key_pressed(KEY_SHIFT)
	
	lasso_allowed = true
	G.wire_from.clear()
	queue_redraw()

func start_via_wiring(sock_data:Dictionary):
	lasso_allowed = false
	G.wire_from = sock_data
	queue_redraw()

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
	#NOTE: we can't stop the timer because the Network relies on it for removing or adding Network Nodes.
	sim_paused = true
func resume_sim():
	sim_paused = false
func reset_sim():
	for link in Net.the_links:
		Net.the_links[link] = link.default

var gizmos : Array[FlowchartGizmo]
func _on_sim_update():
	var begin_time := Time.get_ticks_usec()
	in_a_cycle = true
	sim_cycle_started.emit()
	
	gizmos.clear()
	for lay in Net.netlist.gizmos:
		gizmos.append_array(Net.netlist.gizmos[lay])
	
	Net.cycle_begin()
	
	if not (skip_cycle or sim_paused):
		for port in Net.ports:
			for vert in port.verts:
				vert.cycle_begin(port)
		
		sim_update_started.emit()
		for port in Net.ports:
			for vert in port.verts:
				vert.cycle_update(port)
		sim_update_finish.emit()
	
		for port in Net.ports:
			for vert in port.verts:
				vert.cycle_finish(port)
	
	Net.cycle_finish()
	
	sim_cycle_finish.emit()
	in_a_cycle = false
	skip_cycle = false
	tick_elapse = (Time.get_ticks_usec() - begin_time) / 1_000_000.0  # microseconds it took for all nodes to be done.
#endregion
