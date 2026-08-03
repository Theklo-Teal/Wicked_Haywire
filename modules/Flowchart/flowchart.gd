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

#NOTE To have sockets that hang halfway around the edge, we have to do a visual trick.
# Actually doing this would make it hard to mouse over sockets at the edge, so instead
# we have an undersized panel shape (by 0.5) and then we can still have sockets totally
# enclose the Gizmo area while it looks like they hang off.

#TODO Allow Rotating and Mirroring Graph Nodes
#TODO Procedural Nodes
#TODO Check if I can actually save the network and reload it.
#TODO Allow Copy, Paste and Duplicate
#TODO Allow Undo/Redo: Class UndoRedo
#TODO Joints scaling with zoom

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

const SNAP = 12  ## Size of grid SNAPping cells. The snap grid is based on a rhombus. Refer to [code]Flowchart.to_grid()[/code] for more information.
const VIA_HOLE = 4  ## Radius of the holes in joints.
const MAX_WIRE = 8  ## Maximum thickness of a wire.
const CLEARANCE = 2  ## Minimum distance between conductors.
const JOINT_RAD = 6
static func snap_grid(pos:Vector2) -> Vector2:
	return pos.snappedf(SNAP)
## Returns the actual space position snapped to the grid from a grid coordinate.
static func from_grid(coord:Vector2i) -> Vector2:
	return Vector2(coord) * SNAP
## Returns [code]coord[/code] on the grid.
static func to_grid(pos:Vector2) -> Vector2i:
	var coord := Vector2i(  ## Find cell coordinate in the grid
		roundi(inverse_lerp(0, SNAP, pos.x)),
		roundi(inverse_lerp(0, SNAP, pos.y))
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
var layer : int = 0

enum Mode{
	EDITING,  ## Nodes being repositioned and sockets being connected.
	SIMULAT,  ## Node children being interacted with and their state affected manually.
}
var mode : Mode : 
	set(val):
		mode = val
		for gizmo : FlowchartGizmo in $Network.netlist.gizmos.get(layer, []):
			gizmo._on_flowchart_mode_changed(mode)

func _ready() -> void:
	if not OS.has_feature("debug"): $coord.hide()
	if OS.has_feature("editor_hint"): return
	
	G.chart = self
	for gizmo_file in DirAccess.get_files_at("res://gizmos/"):
		if not gizmo_file.get_extension() in ["gd", "tscn"]: continue
		gizmo_pallet[gizmo_file.get_basename()] = load("res://gizmos/" + gizmo_file)
	
	%zoom.pressed.connect(_on_zoom_pressed)
	%origin.pressed.connect(_on_origin_pressed)
	%zoom.text = str(roundi(zoom * 100)) + " %"
	%LineEdit.text_submitted.connect(_on_line_edit_submit)
	$Canvas_Menu.index_pressed.connect(_on_popup_pressed)
	
	$Input.now().enter()
#endregion

#region Drawing
var _visible_links : PackedInt64Array

func draw_back_geometry(viewed_canvas_rect:Rect2):
	if OS.has_feature("editor_hint"): return
	
	_visible_links.clear()
	
	for joint in parti.joint.find_objects_simple(viewed_canvas_rect):
		#TODO don't track GizmoSockets. We use Gizmo search to tell if to draw these.
		if not joint is GizmoSocket:
			if joint.layer == layer:
				var where = from_grid(joint.coord)
				joint.draw(self, self, to_screen_coord(where))
				for link in $Network.netlist.get_links(joint, true, false):
					_visible_links.append(link)

func draw_fore_geometry(canvas:Control, viewed_canvas_rect:Rect2):
	if OS.has_feature("editor_hint"): return
	
	# Drawing Gizmo sockets
	for gizmo : FlowchartGizmo in parti.node.find_objects_simple(viewed_canvas_rect):
		for coord in gizmo._sockdex:
			var socket = gizmo._sockdex[coord]
			var where = gizmo.get_socket_canvas_position(socket)
			socket.draw(self, canvas, to_screen_coord(where))
			for link in $Network.netlist.get_links(socket, true, false):
				_visible_links.append(link)
	
	# Drawing Wires
	for link in _visible_links:
		var wire : NetBase.Link = $Network.netlist.links[link]
		var pair : Array[NetBase.NetVert]
		pair.assign($Network.netlist.pairs[link])
		var pos1 = $Network.netlist.sockets.get(pair[0]).get_socket_canvas_position(pair[0]) if pair[0] in $Network.netlist.sockets else from_grid(pair[0].coord)
		var pos2 = $Network.netlist.sockets.get(pair[1]).get_socket_canvas_position(pair[1]) if pair[1] in $Network.netlist.sockets else from_grid(pair[1].coord)
		wire.draw(self, canvas, to_screen_coord(pos1), to_screen_coord(pos2))
	
	
func draw_overlay(canvas:Control, _viewed_canvas_rect:Rect2):
	if OS.has_feature("editor_hint"): return
	
	$coord.text = str(to_canvas_coord(get_local_mouse_position()))
	$coord.position = get_local_mouse_position() + Vector2(0, -24)
	
	# Draw wire being pulled.
	if $Input.at("wire_create") or $Input.at("wire_split") and not wire_from.is_empty():
		NetBase.Link.draw_length(canvas, to_screen_coord(wire_from.canvas_position), get_local_mouse_position(), Input.is_key_pressed(KEY_SHIFT), SNAP, trace_color_highlight)
	
	# Highlight grid cell under mouse.
	var where = to_screen_coord(snap_grid(to_canvas_coord(get_local_mouse_position())) + Vector2(0.5, 0.5) * SNAP)
	var clr = G.appearance.color.inverted()
	clr.a = 0.4
	canvas.draw_circle(where, JOINT_RAD, clr)

#endregion

#region Input Handling
func _gui_input(event: InputEvent) -> void:
	super(event)
	
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT and not is_moving_obj:
				_selected.clear()
			$Input.now().mouse_gui_press(
				event.button_index,
				Input.is_key_pressed(KEY_SHIFT),
				Input.is_key_pressed(KEY_CTRL),
				)
		elif event.is_released():
			$Input.now().mouse_gui_release(
				event.button_index,
				Input.is_key_pressed(KEY_SHIFT),
				Input.is_key_pressed(KEY_CTRL),
				)

func _input(event: InputEvent) -> void:
	super(event)
	
	if event is InputEventKey and not event.is_echo():
		if event.keycode == KEY_DELETE and $Input.at("idle"):
			queue_redraw()
			if not sel_wire.is_empty():
				$Network.netlist.pairs.erase(sel_wire.pair_hash)
				$Network.netlist.links.erase(sel_wire.pair_hash)
				sel_wire.clear()
			else:
				for each in _selected:
					if each is FlowchartGizmo:
						rem_gizmo(each)
					if each is FlowchartVia:
						rem_via(each)
			_selected.clear()
			
		if event.keycode == KEY_SHIFT:
			$Input.now().shifted(event.is_pressed())
		if event.keycode == KEY_CTRL:
			$Input.now().ctrled(event.is_pressed())
	
	if event is InputEventMouseButton:
		if event.is_pressed():
			$Input.now().mouse_press(
				event.button_index,
				Input.is_key_pressed(KEY_SHIFT),
				Input.is_key_pressed(KEY_CTRL),
				)
		elif event.is_released():
			$Input.now().mouse_release(
				event.button_index,
				Input.is_key_pressed(KEY_SHIFT),
				Input.is_key_pressed(KEY_CTRL),
				)
		
			if event.button_index == MOUSE_BUTTON_LEFT:
				move_obj_allowed = true
				selected_obj_movement_stop()
	
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_moving_obj and not _selected.is_empty():
			selected_obj_movement_start()
		elif not is_moving_obj:
			$Input.now().mouse_move(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), 
				Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT),
				Input.is_key_pressed(KEY_SHIFT),
				Input.is_key_pressed(KEY_CTRL),
				)

var past_via_coord : Dictionary[NetBase.Joint, Vector3i]
func _selected_obj_movement_start(obj):
	if obj is NetBase.Joint:
		past_via_coord[obj] = Vector3i(obj.coord.x, obj.coord.y, obj.layer)
func _selected_obj_movement_stop(obj):
	if obj is NetBase.Joint:
		$Network.netlist.vias.erase(past_via_coord[obj])
		$Network.netlist.vias[Vector3i(obj.coord.x, obj.coord.y, obj.layer)] = obj
func selected_obj_movement_stop():
	super()
	# Ensure the Dictionary doesn't just keep growing.
	past_via_coord.clear()
func obj_movement_modulate(object, new_position:Vector2) -> Vector2:
	if object is FlowchartGizmo:
		return snap_grid(new_position)
	return snap_grid(new_position)

func escape_key_action():
	$Input.now().cancel()
	super()

func _on_line_edit_submit(_txt:String):
	match %LineEdit.placeholder_text:
		"Tunnel Name":
			pass
		"Gizmo Name":
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
			var node = load("res://modules/Flowchart/Gizmos/info_panel.tscn").instantiate()
			add_gizmo(node, to_canvas_coord(fin_mouse))
		"Ammeter":
			pass
		"Voltmeter":
			pass
		"Bundle":
			pass
		"Gate":
			pass


#region Gizmos
func add_gizmo(res:String, where:=Vector2.ZERO) -> FlowchartGizmo:
	var gizmo = gizmo_pallet.get(res)
	if gizmo is Script:
		gizmo = gizmo.new()
	elif gizmo is PackedScene:
		gizmo = gizmo.instantiate()
	where = snap_grid(where)
	place_object(gizmo, where, parti.node)
	$Network.register_gizmo(gizmo, layer)
	gizmo._on_flowchart_mode_changed(mode)
	return gizmo

func rem_gizmo(gizmo:FlowchartGizmo):
	queue_redraw()
	$Network.unregister_gizmo(gizmo, layer)
	remove_object(gizmo)
	gizmo.queue_free()

func add_via(where:Vector2) -> FlowchartVia:
	queue_redraw()
	var via = $Network.get_or_add_vert(where, layer, FlowchartVia.new())
	place_object(via, via.position, parti.joint)
	return via

func rem_via(via:FlowchartVia):
	queue_redraw()
	$Network.rem_vert(via)
	remove_object(via)

#endregion

#endregion

#region Wiring
# Wire info
var wiring_allowed : bool = true
var wire_from : Dictionary
var sel_wire : Dictionary
var sel_vert : NetBase.NetVert

## Gizmo socket has started a wire.
func start_socket_wiring(sock_data:Dictionary):
	wire_from = sock_data
	sel_vert = sock_data.netvert
	$Input.set_mode("wire_create")

## Wire stopped at a Gizmo socket.
func stop_socket_wiring(sock_data:Dictionary):
	if not ($Input.at("wire_create") or $Input.at("wire_split")): return
	if wire_from.is_empty(): return
	if sock_data.netvert == wire_from.netvert: return
	sel_vert = sock_data.netvert
	$Input.now().finish_wiring(wire_from.netvert, sel_vert,
		Input.is_key_pressed(KEY_SHIFT), Input.is_key_pressed(KEY_CTRL))

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
	for link in $Network.the_links:
		$Network.the_links[link] = link.default

var gizmos : Array[FlowchartGizmo]
func _on_sim_update():
	var begin_time := Time.get_ticks_usec()
	in_a_cycle = true
	sim_cycle_started.emit()
	
	gizmos.clear()
	for lay in $Network.netlist.gizmos:
		gizmos.append_array($Network.netlist.gizmos[lay])
	
	$Network.cycle_begin()
	
	if not (skip_cycle or sim_paused):
		for port in $Network.ports:
			for vert in port.verts:
				vert.cycle_begin(port)
		
		sim_update_started.emit()
		for port in $Network.ports:
			for vert in port.verts:
				vert.cycle_update(port)
		sim_update_finish.emit()
	
		for port in $Network.ports:
			for vert in port.verts:
				vert.cycle_finish(port)
	
	$Network.cycle_finish()
	
	sim_cycle_finish.emit()
	in_a_cycle = false
	skip_cycle = false
	tick_elapse = (Time.get_ticks_usec() - begin_time) / 1_000_000.0  # microseconds it took for all nodes to be done.
#endregion
