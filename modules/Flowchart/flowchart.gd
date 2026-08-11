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
## Finally, graph nodes, or class FlowchartPanel derivations contain Sockets as
## child nodes that automatically position to respect a snapping grid. Just don't
## forget to register them in the [code]FlowchartPanel.sockets[/code] dictionary.[br]
## You are meant to be at the root of a scene and extended to define the behavior
## of their sockets. The can read or write to Links during the update part of the
## simulation cycle. The typical idea is to read from ChartSocketSink nodes, transform the
## value to something meaningful and write with ChartSocketSource nodes.[br]
## These classes of these sockets can be extended for different kinds of signals
## or protocols, thus different Links, thus different Wires.


#TODO Allow Rotating and Mirroring Graph Nodes
#TODO Procedural Nodes
#TODO Check if I can actually save the network and reload it.
#TODO Allow Copy, Paste and Duplicate
#TODO Allow Undo/Redo: Class UndoRedo
#TODO Joints scaling with zoom

enum Mode{
	EDITING,  ## Nodes being repositioned and sockets being connected.
	SIMULAT,  ## Node children being interacted with and their state affected manually.
}

@export var update_rate : float = 0.01 :  # Time for the simulation to update state.
	set(val):
		update_rate = max(0, val)
@export var trace_color_primary := Color.GOLDENROD
@export var trace_color_secondary := Color.GOLD
@export var trace_color_highlight := Color.YELLOW

var mode : Mode : 
	set(val):
		mode = val
		for gizmo : FlowchartPanel in $Network.netlist.gizmos.get(layer, []):
			gizmo._on_flowchart_mode_changed(self, mode)
var gizmo_pallet : Dictionary[String, PackedScene]
var layer : int = 0
var wire_from : Dictionary
var sel_wire : Dictionary
var sel_vert : NetBase.NetVert

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
const SNAP = 24  ## Size of grid SNAPping cells. The snap grid is based on a rhombus. Refer to [code]Flowchart.to_grid()[/code] for more information.
const VIA_HOLE = 5  ## Radius of the holes in joints.
const MAX_WIRE = 20  ## Maximum thickness of a wire.
const CLEARANCE = 2  ## Minimum distance between conductors.
const JOINT_RAD = 12
static func snap_grid(pos:Vector2) -> Vector2:
	return pos.snappedf(SNAP) + (Vector2(0.5, 0.5) * SNAP)
## Returns the actual space position snapped to the grid from a grid coordinate.
static func from_grid(coord:Vector2i) -> Vector2:
	return Vector2(coord) * SNAP + (Vector2(0.5, 0.5) * SNAP)
## Returns [code]coord[/code] on the grid.
static func to_grid(pos:Vector2) -> Vector2i:
	pos -= Vector2(0.5, 0.5) * SNAP
	var coord := Vector2i(  ## Find cell coordinate in the grid
		roundi(inverse_lerp(0, SNAP, pos.x)),
		roundi(inverse_lerp(0, SNAP, pos.y))
		)
	return coord
#endregion

#region State Machine Stuff
func _on_curr_state_set(val:StringName):
	super(val)
	if is_node_ready(): %state.text = val

class Hover extends State:
	func enter(_prev:StringName):
		if me.mode == Flowchart.Mode.SIMULAT:
			switch_state.emit("Interact")
		if not "position" in me._hover_object:
			switch_state.emit("Idle")
	
	func hover_object(object):
		if object == null:
			switch_state.emit("Idle")
	
	func drag_started(drag_button:MouseButton) -> bool:
		if drag_button == MOUSE_BUTTON_LEFT:
			if me.hover_object is FlowchartGizmo and me.hover_object._hover_socket != null:
				me.sel_vert = me.hover_object._hover_socket
				switch_state.emit("Wire")
			else:
				switch_state.emit("Move")
			return true
		return false
	
	func drag_stopped(_drag_button:MouseButton):
		if me.hover_object is FlowchartGizmo and me.hover_object._hover_socket != null:
			me.wire_from = {
				"netvert": me.hover_object._hover_socket,
				"coord": me.hover_object._hover_socket.coord,
				"position": me.hover_object.canvas_socket_position(),
				}
		switch_state.emit("Wire")

class Interact extends State:
	func hover_object(object):
		if object == null:
			switch_state.emit("Idle")

class Wire extends State:
	func enter(prev:StringName):
		var origin = find_origin()
		var destin = find_destin()
		if origin == null or destin == null:
			switch_state.emit(prev)
		finish_wire(origin, destin, Input.is_key_pressed(KEY_SHIFT))
	
	func find_origin() -> NetBase.NetVert:
		return null
	func find_destin() -> NetBase.NetVert:
		return null
	func finish_wire(origin, destin, shift:bool):
		pass

#endregion

func _ready() -> void:
	if not OS.has_feature("debug"):
		$state_info.hide()
		%coord.hide()
		
	if OS.has_feature("editor_hint"): return
	G.chart = self
	
	# Special devices that don't appear in the Toybox.
	gizmo_pallet["_info_panel"] = load("uid://biwbp7mhl3co")
	gizmo_pallet["_buffer_gate"] = load("uid://ddbqln6sbtevv")
	
	%zoom.pressed.connect(_on_zoom_pressed)
	%origin.pressed.connect(_on_origin_pressed)
	%zoom.text = str(roundi(zoom * 100)) + " %"
	%LineEdit.text_submitted.connect(_on_line_edit_submit)
	$Canvas_Menu.index_pressed.connect(_on_popup_pressed)


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

func _on_popup_pressed(idx:int):
	match $Canvas_Menu.get_item_text(idx):
		"Info Panel":
			add_gizmo("_info_panel", to_canvas_coord(ini_mouse))
		"Bundle":
			add_gizmo("_bundle", to_canvas_coord(ini_mouse))
		"Gate":
			add_gizmo("_buffer_gate", to_canvas_coord(ini_mouse))



func get_netlist() -> FlowchartNetwork.NetData:
	return $Network.netlist

func set_netlist(netdata:FlowchartNetwork.NetData):
	$Network.netlist = netdata

func add_gizmo(res:String, where:=Vector2.ZERO) -> FlowchartPanel:
	var gizmo = gizmo_pallet.get(res)
	gizmo = gizmo.instantiate()
	where = snap_grid(where)
	place_object(gizmo, where, parti.node)
	$Network.register_gizmo(gizmo, layer)
	gizmo._on_flowchart_mode_changed(self, mode)
	return gizmo

func rem_gizmo(gizmo:FlowchartPanel):
	queue_redraw()
	$Network.unregister_gizmo(gizmo, layer)
	remove_object(gizmo)
	gizmo.queue_free()

func add_via(where:Vector2) -> FlowchartVia:
	#TODO Check if this is positioning vias correctly.
	queue_redraw()
	var via = $Network.get_or_add_via(to_grid(where), layer, FlowchartVia.new())
	place_object(via, via.position, parti.joint)
	return via

func rem_via(via:FlowchartVia):
	queue_redraw()
	$Network.rem_vert(via)
	remove_object(via)

#region Simulation Implementation
signal sim_cycle_started
signal sim_update_started
signal sim_update_finish
signal sim_cycle_finish
signal auto_paused
#signal auto_resume

var in_a_cycle : bool = false
var skip_cycle : bool = false
var sim_paused : bool = false
var tick_elapse : float = 0
var process_elapse : float = 0
var tick_countdown : int = -1

func _process(delta: float) -> void:
	if OS.has_feature("editor_hint"): return
	process_elapse += delta
	if process_elapse > update_rate:
		process_elapse = 0.0
		if in_a_cycle:
			skip_cycle = true
			printerr("Flowchart: Simulation Rate not keeping up with cycle duration!")
		_on_sim_update()

func pause_sim():
	#NOTE: we can't stop the timer because the Network relies on it for removing or adding Network Nodes.
	sim_paused = true
## Run simulation cycles. If duration is a positive value, it will pause itself
## after that amount of cycles, after which the signal [code]auto_pause[/code]
## is emitted.
func resume_sim(duration:int = -1):
	sim_paused = false
	tick_countdown = duration - 1
func reset_sim():
	$Network.reset_simulation()

func _on_sim_update():
	var begin_time := Time.get_ticks_usec()
	
	if not skip_cycle:
		in_a_cycle = true
		sim_cycle_started.emit()
		
		$Network.sim_cycle_begin()
		
		if not sim_paused:
			if tick_countdown == 0:
				pause_sim()
				auto_paused.emit()
			elif tick_countdown > 0: tick_countdown -= 1
			
			sim_update_started.emit()
			$Network.sim_cycle_update()
			await $Network.sim_update_done
			sim_update_finish.emit()
		
		$Network.sim_cycle_finish()
		
		sim_cycle_finish.emit()
	in_a_cycle = false
	skip_cycle = false
	tick_elapse = (Time.get_ticks_usec() - begin_time) / 1_000_000.0  # microseconds it took for all nodes to be done.
#endregion
