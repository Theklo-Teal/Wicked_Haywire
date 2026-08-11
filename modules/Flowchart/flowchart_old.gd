@tool
extends InfiCanvas

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
#
#@export var update_rate : float = 0.01 :  # Time for the simulation to update state.
	#set(val):
		#update_rate = max(0, val)
#@export var trace_color_primary := Color.GOLDENROD
#@export var trace_color_secondary := Color.GOLD
#@export var trace_color_highlight := Color.YELLOW
#
#func _on_appearance_changed():
	#cell_size = G.appearance.cell_size
	#color = G.appearance.color
	#orig_color = G.appearance.orig_color
	#grid_color = G.appearance.grid_color
	#grid_thick = G.appearance.grid_thick
	#orig_thick = G.appearance.orig_thick
	#trace_color_primary = G.appearance.trace_primary
	#trace_color_secondary = G.appearance.trace_secondary
	#trace_color_highlight = G.appearance.trace_highlight
#
##region Grid Snapping
#
#const SNAP = 24  ## Size of grid SNAPping cells. The snap grid is based on a rhombus. Refer to [code]Flowchart.to_grid()[/code] for more information.
#const VIA_HOLE = 5  ## Radius of the holes in joints.
#const MAX_WIRE = 20  ## Maximum thickness of a wire.
#const CLEARANCE = 2  ## Minimum distance between conductors.
#const JOINT_RAD = 12
#static func snap_grid(pos:Vector2) -> Vector2:
	#return pos.snappedf(SNAP) + (Vector2(0.5, 0.5) * SNAP)
### Returns the actual space position snapped to the grid from a grid coordinate.
#static func from_grid(coord:Vector2i) -> Vector2:
	#return Vector2(coord) * SNAP + (Vector2(0.5, 0.5) * SNAP)
### Returns [code]coord[/code] on the grid.
#static func to_grid(pos:Vector2) -> Vector2i:
	#pos -= Vector2(0.5, 0.5) * SNAP
	#var coord := Vector2i(  ## Find cell coordinate in the grid
		#roundi(inverse_lerp(0, SNAP, pos.x)),
		#roundi(inverse_lerp(0, SNAP, pos.y))
		#)
	#return coord
##endregion
#
#func _process(delta: float) -> void:
	#if OS.has_feature("editor_hint"): return
	#process_elapse += delta
	#if process_elapse > update_rate:
		#process_elapse = 0.0
		#if in_a_cycle:
			#skip_cycle = true
			#printerr("Flowchart: Simulation Rate not keeping up with cycle duration!")
		#_on_sim_update()
#
##region Boilerplate
#var gizmo_pallet : Dictionary[String, PackedScene]
#var layer : int = 0
#
#enum Mode{
	#EDITING,  ## Nodes being repositioned and sockets being connected.
	#SIMULAT,  ## Node children being interacted with and their state affected manually.
#}
#var mode : Mode : 
	#set(val):
		#mode = val
		#for gizmo : FlowchartPanel in $Network.netlist.gizmos.get(layer, []):
			#gizmo._on_flowchart_mode_changed(self, mode)
		#match val:
			#Mode.EDITING:
				#wiring_allowed = true
			#Mode.SIMULAT:
				#wiring_allowed = false
	#
	#
#func _ready() -> void:
	#if not OS.has_feature("debug"): %coord.hide()
	#if OS.has_feature("editor_hint"): return
	#
	#G.chart = self
	#
	## Special devices that don't appear in the Toybox.
	#gizmo_pallet["_info_panel"] = load("uid://biwbp7mhl3co")
	#gizmo_pallet["_buffer_gate"] = load("uid://ddbqln6sbtevv")
	#
	#%zoom.pressed.connect(_on_zoom_pressed)
	#%origin.pressed.connect(_on_origin_pressed)
	#%zoom.text = str(roundi(zoom * 100)) + " %"
	#%LineEdit.text_submitted.connect(_on_line_edit_submit)
	#$Canvas_Menu.index_pressed.connect(_on_popup_pressed)
	#
	#$Act.now().enter()
#
#func get_netlist() -> FlowchartNetwork.NetData:
	#return $Network.netlist
#
#func set_netlist(netdata:FlowchartNetwork.NetData):
	#$Network.netlist = netdata
##endregion
#
##region Drawing
#var _visible_links : Dictionary
#
#func draw_back_geometry(viewed_canvas_rect:Rect2):
	#if OS.has_feature("editor_hint"): return
	#
	#_visible_links.clear()
	#
	#for joint in parti.joint.find_objects_simple(viewed_canvas_rect):
		##TODO don't track GizmoSockets. We use Gizmo search to tell if to draw these.
		#if not joint is GizmoSocket:
			#if joint.layer == layer:
				#var where = from_grid(joint.coord)
				#joint.draw(self, self, to_screen_coord(where))
				#for link in $Network.netlist.get_links(joint, true, false):
					#_visible_links[link] = null

#func draw_fore_geometry(canvas:Control, viewed_canvas_rect:Rect2):
	#if OS.has_feature("editor_hint"): return
	#
	## Drawing Gizmo sockets
	#for gizmo : FlowchartPanel in parti.node.find_objects_simple(viewed_canvas_rect):
		#if gizmo.get("sockets") == null: continue
		#for coord in gizmo._sockdex:
			#var socket = gizmo._sockdex[coord]
			#for link in $Network.netlist.get_links(socket):
				#_visible_links[link] = null
	#
	## Drawing Wires
	#for link in _visible_links:
		#var wire : NetBase.Link = $Network.netlist.links[link]
		#var pair : Array[NetBase.NetVert]
		#pair.assign($Network.netlist.pairs[link])
		#var pos1 = $Network.netlist.sockets.get(pair[0]).canvas_socket_position(pair[0]) if pair[0] in $Network.netlist.sockets else from_grid(pair[0].coord)
		#var pos2 = $Network.netlist.sockets.get(pair[1]).canvas_socket_position(pair[1]) if pair[1] in $Network.netlist.sockets else from_grid(pair[1].coord)
		#wire.draw(self, canvas, to_screen_coord(pos1), to_screen_coord(pos2))


#func draw_overlay(canvas:Control, _viewed_canvas_rect:Rect2):
	#if OS.has_feature("editor_hint"): return
	#
	#%coord.text = str(to_canvas_coord(get_local_mouse_position()))
	#%coord.position = get_local_mouse_position() + Vector2(0, -24)
	#
	## Draw wire being pulled.
	#if $Act.at("wire_mode") and not wire_from.is_empty():
		#var wire_type = $Network.link_classes[wire_from.netvert.port.default_link()]
		#var thickness = wire_type._wire_thick()
		#thickness = clamp(thickness, 1, MAX_WIRE) * zoom
		#NetBase.Link.draw_length(canvas, to_screen_coord(wire_from.canvas_position), get_local_mouse_position(), Input.is_key_pressed(KEY_SHIFT), thickness, SNAP, trace_color_highlight)
	#
	## Highlight grid cell under mouse.
	#var where = to_canvas_coord(get_local_mouse_position(), -Vector2(0.5, 0.5) * SNAP)
	#where = to_screen_coord( snap_grid(where) )
	#var clr = G.appearance.color.inverted()
	#clr.a = 0.4
	#canvas.draw_circle(where, JOINT_RAD * zoom, clr)

#endregion

#region Input Handling
#func _gui_input(event: InputEvent) -> void:
	#super(event)
	#
	#if _hover_object != null: return
	#
	#if event is InputEventMouseButton:
		#if event.is_pressed():
			#var grab_gizmo = G.grabbed_buttons.get_pressed_button()
			#if not is_moving_obj:
				#if event.button_index == MOUSE_BUTTON_LEFT:
					#if grab_gizmo != null:
						#add_gizmo(grab_gizmo.get_meta("name"), to_canvas_coord(event.position))
				#
				#if grab_gizmo == null:
					#$Act.now().mouse_gui_press(
						#event.button_index,
						#Input.is_key_pressed(KEY_SHIFT),
						#Input.is_key_pressed(KEY_CTRL),
						#)
		#elif event.is_released():
			#$Act.now().mouse_gui_release(
				#event.button_index,
				#Input.is_key_pressed(KEY_SHIFT),
				#Input.is_key_pressed(KEY_CTRL),
				#)

#func _input(event: InputEvent) -> void:
	#super(event)
	#
	#if event is InputEventKey and not event.is_echo():
		#if event.keycode == KEY_DELETE and $Act.at("idle") and event.is_released():
			#queue_redraw()
			#if not sel_wire.is_empty():
				#var joints = $Network.netlist.joints_of_hash(sel_wire.pair_hash)
				#$Network.unlink_hash(sel_wire.pair_hash)
				#sel_wire.clear()
			#else:
				#print(sel_vert)
				#for each in _selected:
					#if each is FlowchartPanel:
						#rem_gizmo(each)
					#if each is FlowchartVia:
						#rem_via(each)
			#_selected.clear()
			#
		#if event.keycode == KEY_SHIFT:
			#$Act.now().shifted(event.is_pressed())
		#if event.keycode == KEY_CTRL:
			#$Act.now().ctrled(event.is_pressed())
	#
	#if event is InputEventMouseButton:
		#if event.is_pressed() and _hover_object == null:
			#$Act.now().mouse_press(
				#event.button_index,
				#Input.is_key_pressed(KEY_SHIFT),
				#Input.is_key_pressed(KEY_CTRL),
				#)
		#elif event.is_released():
			#if  _hover_object == null:
				#$Act.now().mouse_release(
					#event.button_index,
					#Input.is_key_pressed(KEY_SHIFT),
					#Input.is_key_pressed(KEY_CTRL),
					#)
			#if event.button_index == MOUSE_BUTTON_LEFT:
				#selected_obj_movement_stop()
	#
	#if event is InputEventMouseMotion:
		#if not is_moving_obj and mode == Mode.EDITING:
			#move_obj_allowed = _hover_object != null
			#if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _selected.is_empty():
				#selected_obj_movement_start()
			#else:
				#$Act.now().mouse_move(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), 
					#Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT),
					#Input.is_key_pressed(KEY_SHIFT),
					#Input.is_key_pressed(KEY_CTRL),
					#)
#
#func _set_hover_object(val):
	## NOTE Gizmos set themselves to the `_hover_object` variable.
	#super(val)
#
#var past_via_coord : Dictionary[NetBase.Joint, Vector3i]
#var last_valid_pos : Dictionary[NetBase.Joint, Vector2i]
#func selected_obj_movement_stop():
	#super()
	## Ensure the Dictionary doesn't just keep growing.
	#past_via_coord.clear()
#func _selected_obj_movement_start(obj):
	#if obj is NetBase.Joint:
		#past_via_coord[obj] = Vector3i(obj.coord.x, obj.coord.y, obj.layer)
#func _selected_obj_movement_stop(obj):
	#if obj is NetBase.Joint:
		#$Network.netlist.vias.erase(past_via_coord[obj])
		#$Network.netlist.vias[Vector3i(obj.coord.x, obj.coord.y, obj.layer)] = obj
#func obj_movement_modulate(object, new_position:Vector2) -> Vector2:
	#if object is FlowchartPanel:
		#queue_redraw()  # Makes wires follow gizmo sockets.
		#return snap_grid(new_position) - Vector2(0.5, 0.5) * SNAP
	#if object is NetBase.Joint:
		#var cell := to_grid(position)
		#if Vector3i(cell.x, cell.y, layer) in $Network.netlist.vias:
			## Make is so vias can't overlap.
			#return from_grid(last_valid_pos[object]) + Vector2(0.5, 0.5)
		#last_valid_pos[object] = cell
		#return snap_grid(new_position - Vector2(0.5, 0.5) * SNAP)
	#return snap_grid(new_position)
#
#func escape_key_action():
	#$Act.now().cancel()
	##super()
#
#
#
##endregion
#
##region Add or Remove objects
#
#func _on_popup_pressed(idx:int):
	#match $Canvas_Menu.get_item_text(idx):
		#"Info Panel":
			#add_gizmo("_info_panel", to_canvas_coord(ini_mouse))
		#"Bundle":
			#add_gizmo("_bundle", to_canvas_coord(ini_mouse))
		#"Gate":
			#add_gizmo("_buffer_gate", to_canvas_coord(ini_mouse))
#
#
##region Gizmos
#func add_gizmo(res:String, where:=Vector2.ZERO) -> FlowchartPanel:
	#var gizmo = gizmo_pallet.get(res)
	#gizmo = gizmo.instantiate()
	#where = snap_grid(where)
	#place_object(gizmo, where, parti.node)
	#$Network.register_gizmo(gizmo, layer)
	#gizmo._on_flowchart_mode_changed(self, mode)
	#return gizmo
#
#func rem_gizmo(gizmo:FlowchartPanel):
	#queue_redraw()
	#$Network.unregister_gizmo(gizmo, layer)
	#remove_object(gizmo)
	#gizmo.queue_free()
#
#func add_via(where:Vector2) -> FlowchartVia:
	##TODO Check if this is positioning vias correctly.
	#queue_redraw()
	#var via = $Network.get_or_add_via(to_grid(where), layer, FlowchartVia.new())
	#place_object(via, via.position, parti.joint)
	#return via
#
#func rem_via(via:FlowchartVia):
	#queue_redraw()
	#$Network.rem_vert(via)
	#remove_object(via)
#
##endregion
#
##endregion
#
##region Wiring
## Wire info
#var wiring_allowed : bool = true
#var wire_from : Dictionary
#var sel_wire : Dictionary
#var sel_vert : NetBase.NetVert
#
### Gizmo socket has started a wire.
#func start_socket_wiring(sock_data:Dictionary):
	#if $Act.at("idle"):
		#wire_from = sock_data
		#$Act.set_mode("wire_mode")
#
### Wire stopped at a Gizmo socket.
#func stop_socket_wiring(sock_data:Dictionary):
	#if not $Act.at("wire_mode"): return
	#if wire_from.is_empty(): return
	#sel_vert = sock_data.netvert
	#$Act.now().mouse_release(MOUSE_BUTTON_RIGHT,
		#Input.is_key_pressed(KEY_SHIFT), Input.is_key_pressed(KEY_CTRL))
#
##endregion
