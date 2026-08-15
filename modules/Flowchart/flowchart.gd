@tool
extends InfiCanvas
class_name Flowchart

## An Infinite Canvas were you can place panels called "graph nodes", which may
## contain sockets. The sockets can be connected together to form flowchart
## visualizations which can process some operations or simulations for interactive
## and dynamic behaviours between graph nodes.[br]
## The data about the connections of sockets is stored in a FlowchartNetwork.NetData,
## Specifically the instance in the [code]$Network.netlist[/code] variable.[br]
## This is very similar to Godot's GraphEdit node, but being a custom implementation,
## we can make it display things or operate on things in our custom way and without 
## being afraid of the "Experimental" tag.[br][br]
## Networks can be extended to have different sets of Port types, which extend the
## generic "Port" inner class.[br]
## Different Ports carry different formats of data and can behave differently when
## written or read to for simulation.[br]
## The visual representation of connections is the Link class, which can be extended
## To define different ways of rendering the wire.[br]
## The FlowchartSockets can extended to use different Ports types, and ports decide
## a preferred Link type , thus deciding what kind of wire they produce and which
## other sockets they are allowed to connect to.[br]
## Finally, graph nodes, of the class FlowchartGizmo contain a dictionary of Sockets
## that automatically position to respect a snapping grid.


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
var wire_from : NetBase.NetVert
var sel_vert : NetBase.NetVert
var sel_wire : Dictionary

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


#region Utilities
func grid_mouse() -> Vector2i:
	return Flowchart.to_grid(to_canvas_coord(get_local_mouse_position()))
func canvas_mouse() -> Vector2:
	return Flowchart.snap_grid(to_canvas_coord(get_local_mouse_position()))
func screen_mouse() -> Vector2:
	return get_local_mouse_position()
func global_screen_mouse() -> Vector2:
	return get_global_mouse_position()

func joint_canvas_position(joint:NetBase.NetVert) -> Vector2:
	if joint in $Network.netlist.sockets:
		var gizmo : FlowchartGizmo = $Network.netlist.sockets[joint]
		return gizmo.canvas_socket_position(joint)
	else:
		return joint.position

func socket_under_mouse() -> NetBase.Socket:
	hover_object._on_mouse_stopped()  # Force the Gizmo to check socket under mouse.
	#NOTE: Gizmos already check their sockets on click, but they receive input later than Flowchart, so it's moot.
	if hover_object.hover_socket != null:
		return hover_object.hover_socket
	return null

func vert_under_mouse() -> NetBase.NetVert:
	var cell = grid_mouse()
	cell = Vector3i(cell.x, cell.y, layer)
	return $Network.netlist.vias.get(cell, null)

var _wire_skip : int = 0  # (Not implemented yet) If wires overlap, this skips a match if the user wants to.
func wire_under_mouse():
	var conns : Dictionary
	for via in parti.joint.find_objects_simple(_view_rect):
		for link in $Network.netlist.get_links(via):
			conns[link] = false
	for gizmo in parti.node.find_objects(_view_rect):
		if gizmo.get("sockets") == null: continue
		for sock in gizmo.sockets:
			for link in $Network.netlist.get_links(sock):
				conns[link] = false
	var wire_info : Dictionary
	for link in conns:
		var wire = $Network.netlist.links[link]
		var pair = $Network.netlist.pairs[link]
		var pos1 = joint_canvas_position(pair[0])
		var pos2 = joint_canvas_position(pair[1])
		wire_info = wire.near(screen_mouse(), to_screen_coord(pos1), to_screen_coord(pos2))
		if not wire_info.is_empty():
			if _wire_skip <= 0:
				wire_info["wire"] = wire
				wire_info["pair_hash"] = link
				wire_info["ini_bend"] = wire.bend
				break
			else:
				_wire_skip -= 1
	return wire_info
#endregion

#region State Machine Stuff

func _on_curr_state_set(val:StringName):
	super(val)
	if is_node_ready(): %state.text = val

func _selected_changed():
	# Cancels a gizmo from being placed if clicked on a canvas gizmo.
	var grab_gizmo = G.grabbed_buttons.get_pressed_button()
	if grab_gizmo != null: grab_gizmo.button_pressed = false

func _obj_movement_modulate(object, new_position:Vector2) -> Vector2:
	if object is FlowchartPanel:
		return snap_grid(new_position) - Vector2(0.5, 0.5) * SNAP
	#NOTE the way repositioning Vias works is that we maintain their `coord`
	# untouched. We only change the `position` and drawing functions use that
	# variable as well. After the movement stops, we call `Flowchart.move_via()`
	# which sets the new `coord`, given the final position.
	# Changing `coord` directly messes up with `move_via()` and we need that
	# to update spatial partitioning and netlist.
	return snap_grid(new_position)

func _selected_obj_movement_stop(obj):
	if obj is FlowchartVia:
		move_via(obj, to_grid(obj.position))

func lasso_select_objects(lasso_rect:Rect2) -> void:
	var gizmos : Array = [parti.node.find_objects_tolerant, parti.node.find_objects_zealous][chirality].call(lasso_rect)
	var vias : Array = parti.joint.find_objects_simple(lasso_rect)
	if Input.is_key_pressed(KEY_SHIFT):
		add_selected.callv(gizmos + vias)
	else:
		set_selected.callv(gizmos + vias)


func on_vert_selected(vert:NetBase.NetVert):
	sel_vert = vert
	hover_object = vert
	if sel_vert == null: return
	if Input.is_key_pressed(KEY_SHIFT):
		add_selected(sel_vert)
	else:
		set_selected(sel_vert)

func on_wire_selected(wire:Dictionary):
	sel_wire = wire
	if wire: return false
	var moved_joint : Array
	moved_joint.assign( $Network.netlist.pairs.get(sel_wire.pair_hash).duplicate() )
	# If the joint is part of a gizmo, we use the gizmo instead for repositioning.
	moved_joint[0] = $Network.netlist.sockets.get(moved_joint[0], moved_joint[0])
	moved_joint[1] = $Network.netlist.sockets.get(moved_joint[1], moved_joint[1])
	#if Input.is_key_pressed(KEY_SHIFT):
		#add_selected(moved_joint)
	#else:
		#set_selected(moved_joint)


signal picked_gizmo(gizmo:FlowchartGizmo)
## Sets a grabbed gizmo with the same settings as the picked one.
func picker_tool(gizmo:FlowchartGizmo):
	picked_gizmo.emit(gizmo)


class ChartIdle extends Idle:
	static func override_state() -> StringName:
		return &"Idle"
	
	func gui_input(event:InputEvent):
		super(event)
		
		if event is InputEventMouseButton:
			if event.is_pressed():
				me.queue_redraw()
				me.sel_wire.clear()
				var vert = me.vert_under_mouse()
				if vert == null:
					var wire = me.wire_under_mouse()
					if not wire.is_empty():
						me.on_wire_selected(wire)
				else:
					me.on_vert_selected(vert)
					
			if event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
				if me.sel_wire.is_empty() and me.sel_vert == null:
						my("Canvas_Menu").popup(Rect2(me.global_screen_mouse(), Vector2.ZERO))
				elif not me.sel_wire.is_empty():
					if Input.is_key_pressed(KEY_CTRL):
						# Open some wire menu.
						pass
					elif floori(me.sel_wire.subratio) == 1:
						switch_state.emit("WireBend")
					else:  # Wire splitting
						switch_state.emit("Wire")
			elif event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
				if me.sel_vert == null:
					var grab_gizmo = G.grabbed_buttons.get_pressed_button()
					if grab_gizmo != null:
						me.add_gizmo(grab_gizmo.get_meta("name"), me.canvas_mouse())

class ChartHover extends Hover:
	static func override_state() -> StringName:
		return &"Hover"
	
	func enter(prev:StringName):
		super(prev)
		if me.mode == Flowchart.Mode.SIMULAT:
			switch_state.emit("Interact")
	
	func input(event:InputEvent):
		super(event)
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if event.is_pressed():
					me.wire_from = null  # Probably pointless, but just to make sure.
					if me.hover_object is FlowchartGizmo:
						if Input.is_key_pressed(KEY_CTRL):
							me.picker_tool(me.hover_object)
						else:
							me.wire_from = me.socket_under_mouse()
					elif me.hover_object is FlowchartVia:
						me.wire_from = me.hover_object
					if Input.is_key_pressed(KEY_CTRL) and me.wire_from is FlowchartVia:
						# Popup Via Menu
						pass
					else:
						switch_state.emit("Wire")

class Interact extends State:
	func hover_object(object):
		if object == null:
			switch_state.emit("Idle")

class Wire extends State:
	var origin : NetBase.Joint
	var destin : NetBase.Joint
	
	func cancel():
		if me.hover_object == null: switch_state.emit("Idle")
		else: switch_state.emit("Hover")
	
	func exit(_next:StringName):
		me.queue_redraw()
		me.wire_from = null
		origin = null
		destin = null
	
	func enter(prev:StringName):
		origin = me.wire_from
		if origin == null:
			me.sel_wire = me.wire_under_mouse()
			if me.sel_wire.is_empty():
				switch_state.emit(prev)
			else:
				origin = split_wire(me.sel_wire.pair_hash).netvert
		if origin == null:
			cancel()
	
	func input(event:InputEvent):
		if event is InputEventKey and event.keycode == KEY_SHIFT:
			me.queue_redraw()
		
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			if event.is_released():
				# Find a joint to connect to or create one.
				destin = find_joint()
				if destin == null: cancel(); return
				if origin != destin:
					# Connect Joints
					var wire : NetBase.Link = my("Network").linking(origin, destin)
					var pos1 = me.joint_canvas_position(origin)
					var pos2 = me.joint_canvas_position(destin)
					wire.set_chi_from_len(pos1, pos2, not Input.is_key_pressed(KEY_SHIFT))
					wire.bend = Flowchart.SNAP
					cancel()
				#NOTE if finding a joint fails, we do nothing. The user may try
				# clicking on something again, allowing click-to-click wiring.
	
	func find_joint() -> NetBase.NetVert:
		var joint : NetBase.NetVert
		if me.hover_object is FlowchartGizmo:
			joint = me.socket_under_mouse()
		if joint == null: joint = me.vert_under_mouse()
		if joint == null:
			var wire = me.wire_under_mouse()
			if wire.is_empty():
				joint = me.add_via(me.canvas_mouse())
			else:
				joint = split_wire(me.sel_wire.pair_hash).netvert
		return joint
	
	func split_wire(link:int) -> Dictionary:
		#TODO Check if joint creation logic is correct.
		var wire0 : NetBase.Link = my("Network").netlist.links.get(link)
		var joints = my("Network").netlist.pairs[link]
		var where = wire0.position_along(me.sel_wire.ratio,
			me.joint_canvas_position(joints[0]),
			me.joint_canvas_position(joints[1]))
		var new_joint = me.add_via(where)
		var cell = Flowchart.to_grid(where)
		my("Network").unlink_verts(joints[0], joints[1])
		var wire1 = my("Network").linking(joints[0], new_joint)
		var wire2 = my("Network").linking(new_joint, joints[1])
		wire1.chirality = wire0.chirality
		wire2.chirality = wire0.chirality
		wire1.bend = wire0.bend
		wire2.bend = wire0.bend
		me.sel_wire.clear()
		return {"netvert": new_joint, "coord": cell, "canvas_position": where}

class WireBend extends State:
	var pair : Array[NetBase.NetVert]
	var joints : Array[Vector2]
	var wire : NetBase.Link

	func cancel():
		me.sel_wire.clear()
		switch_state.emit("Idle")

	func enter(_prev:StringName):
		if me.sel_wire.is_empty(): cancel()
		var link = me.sel_wire.pair_hash
		wire = my("Network").netlist.links[ link ]
		pair.assign( my("Network").netlist.pairs[ link ] )
		joints = [me.joint_canvas_position(pair[0]), me.joint_canvas_position(pair[1])]
	
	func input(event:InputEvent):
		if event is InputEventMouseButton and event.is_released():
			if event.button_index == MOUSE_BUTTON_RIGHT:
				switch_state.emit("Idle")
		
		if event is InputEventMouseMotion:
			me.queue_redraw()
			var diff = joints[0] - joints[1]
			var delta = me.get_local_mouse_position() - me.ini_mouse

			# Find shortest segment, the maximum value of the bend.
			var diff_abs = diff.abs()
			var short_axis = diff_abs.min_axis_index()
			var shortest = diff_abs[short_axis]

			# Find the direction of the bend
			var diff_norm = diff.normalized()
			if wire.chirality:
				diff_norm = Vector2(diff_norm.y, -diff_norm.x)
			else:
				diff_norm = Vector2(-diff_norm.y, diff_norm.x)
			var dir = delta.normalized().dot(diff_norm)

			delta = delta.length() * dir * 2
			var ini_bend : float = me.sel_wire.ini_bend
			wire.bend = clamp(ini_bend + delta, Flowchart.SNAP, shortest)

#endregion


func _ready() -> void:
	if not OS.has_feature("debug"):
		$state_info.hide()
		%coord.hide()
	
	parti["joint" as Variant] = SpatialPartition.new()
	parti["node" as Variant] = SpatialPartition.new()
	
	if OS.has_feature("editor_hint"): return
	G.chart = self
	
	%zoom.pressed.connect(_on_zoom_pressed)
	%origin.pressed.connect(_on_origin_pressed)
	%zoom.text = str(roundi(zoom * 100)) + " %"
	%LineEdit.text_submitted.connect(_on_line_edit_submit)
	$Canvas_Menu.index_pressed.connect(_on_popup_pressed)

func _input(event: InputEvent) -> void:
	super(event)
	
	if event is InputEventKey and not event.is_echo():
		if event.keycode == KEY_DELETE and event.is_released():
			if at_state("Idle", "Hover"):
				queue_redraw()
				if not sel_wire.is_empty():
					$Network.unlink_hash(sel_wire.pair_hash)
					sel_wire.clear()
				else:
					for each in _selected:
						if each is FlowchartPanel:
							rem_gizmo(each)
						if each is FlowchartVia:
							rem_via(each)
				clear_selected()
	
	if event is InputEventMouseMotion:
		if _mouse_stopped:
			_mouse_stopped = false
		_mouse_stopped_frames = 0


const _MOUSE_MOVE_THRESHOLD = 6  # How many process frames have to pass to consider the mouse stopped?
var _mouse_stopped_frames : int  # How many frames the mouse hasn't moved.
var _mouse_stopped : bool = false
func _on_mouse_stopped():
	if hover_object == null or hover_object is FlowchartVia:  # This test makes sure we don't set `hover_object` to a via behind a Gizmo, if the mouse is over a Gizmo.
		hover_object = vert_under_mouse()


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
		"Constant":
			add_gizmo("_constant", to_canvas_coord(ini_mouse))
		"Gate":
			add_gizmo("_buffer_gate", to_canvas_coord(ini_mouse))
		"Maestro":
			add_gizmo("_bundle", to_canvas_coord(ini_mouse))

#region Drawing
var _visible_links : Dictionary
func _draw_back_geometry(canvas:Control, viewed_canvas_rect:Rect2):
	if OS.has_feature("editor_hint"): return
	
	_visible_links.clear()
	
	for joint in parti.joint.find_objects_simple(viewed_canvas_rect):
		# We don't track GizmoSockets here. We use Gizmo search to tell if to find their links.
		if joint is GizmoSocket: continue
		if joint.layer == layer:
			#NOTE, usually we avoid relying on joint `position` as much as we can,
			# but we hope vias can be trusted, otherwise the repositioning by
			# mouse drag needs to be way more complicated.
			# While the mouse drags, we maintain the `coord`as the initial
			# reference position, while changing `position`. Once the drag ends
			# we convert `position` into `coord` and keep things consistent.
			joint.draw(self, canvas, to_screen_coord(joint.position))
			for link in $Network.netlist.get_links(joint):
				_visible_links[link] = null

func _draw_fore_geometry(canvas:Control, viewed_canvas_rect:Rect2):
	if OS.has_feature("editor_hint"): return
	
	# Drawing Gizmo sockets
	for gizmo : FlowchartPanel in parti.node.find_objects_simple(viewed_canvas_rect):
		if gizmo.get("sockets") == null: continue
		for coord in gizmo._sockdex:
			var socket = gizmo._sockdex[coord]
			for link in $Network.netlist.get_links(socket):
				_visible_links[link] = null
	
	# Drawing Wires
	for link in _visible_links:
		var wire : NetBase.Link = $Network.netlist.links[link]
		var pair : Array[NetBase.NetVert]
		pair.assign($Network.netlist.pairs[link])
		var pos1 = joint_canvas_position(pair[0])
		var pos2 = joint_canvas_position(pair[1])
		wire.draw(self, canvas, to_screen_coord(pos1), to_screen_coord(pos2))

func _draw_overlay(canvas:Control, _viewed_canvas_rect:Rect2):
	if OS.has_feature("editor_hint"): return
	
	%coord.text = str(to_canvas_coord(get_local_mouse_position()))
	%coord.position = get_local_mouse_position() + Vector2(0, -24)
	
	# Draw wire being pulled.
	if at_state("Wire") and wire_from != null:
		@warning_ignore("static_called_on_instance")
		var wire_type = $Network.link_classes[wire_from.port.default_link()]
		var thickness = wire_type._wire_thick()
		thickness = clamp(thickness, 1, MAX_WIRE) * zoom
		#FIXME Fixed? For some reason, `Link.set_chi_from_len()` doesn't agree on the effect of `longest` with `Link.draw_length()`
		wire_type.draw_length(canvas, joint_canvas_position(wire_from), get_local_mouse_position(), not Input.is_key_pressed(KEY_SHIFT), thickness, SNAP, trace_color_highlight)
	
	# Highlight grid cell under mouse.
	if at_state("Idle"):
		var where = to_canvas_coord(get_local_mouse_position(), -Vector2(0.5, 0.5) * SNAP)
		where = to_screen_coord( snap_grid(where) )
		var clr = G.appearance.color.inverted()
		clr.a = 0.4
		canvas.draw_circle(where, JOINT_RAD * zoom, clr)

#endregion

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
	queue_redraw()
	var via = $Network.get_or_add_via(to_grid(where), layer, FlowchartVia.new())
	place_object(via, via.position, parti.joint)
	return via

func rem_via(via:FlowchartVia):
	queue_redraw()
	$Network.rem_vert(via)
	remove_object(via)

func move_via(via:FlowchartVia, where:Vector2i) -> Error:
	var error = $Network.move_vert(via, where)
	if error == OK:
		parti.joint.update_object(via)
	return error

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
	super(delta)
	if OS.has_feature("editor_hint"): return

	# Mouse stop detection.
	# The _MOUSE_MOVE_THRESHOLD here acts a bit like an input debouncing mechanism.
	if _mouse_stopped_frames > _MOUSE_MOVE_THRESHOLD and not _mouse_stopped:
		_mouse_stopped = true
		_on_mouse_stopped()
	else:
		_mouse_stopped_frames = _mouse_stopped_frames + 1
		# Keep number above threshold if it wraps around the larges possible int.
		if _mouse_stopped_frames < 0: _mouse_stopped_frames = _MOUSE_MOVE_THRESHOLD
	
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
