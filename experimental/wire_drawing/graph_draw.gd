extends ColorRect
class_name xGraphDraw

#TODO Wire detach (tentative) - Remove wire from a NetVert, to then reattach to another vert.
#TODO Wire Editing (tentative) - Edit the shape of an already existing wire.
#TODO Wire shifting (tentative) - Move two NetVerts together by dragging the wire connecting them.
#TODO Wire merge (tentative) - NetVerts which only two wires are colinear are removed and the a single wire is used to simplify the graph.

const CELL_DIA = 20  ## Size of row cells.
const VIA_RAD = 7  ## Hole size inside sockets
const WIRE_THICK = 8  ## The maximum thickness of a wire.

var sel_vert : xNetVerts.xJoint
var coord_joint : Vector2i  ## Grid coordinate of sel_vert at time of selecting it.
var sel_wire : Dictionary  ## Information about the sel_wire at the time of selecting it.
var detach_wire := false

static func snap_grid(point:Vector2) -> Vector2:
	return point.snappedf(CELL_DIA)

static func from_grid(coord:Vector2i) -> Vector2:
	return Vector2(coord) * CELL_DIA

## Returns the grid cell the point falls into
static func to_grid(point:Vector2) -> Vector2i:
	return Vector2i(  ## Find cell coordinate on the grid
		roundi(inverse_lerp(0, CELL_DIA, point.x)),
		roundi(inverse_lerp(0, CELL_DIA, point.y))
		)

var net := xNetwork.new()

func _ready() -> void:
	for i in range(0, 20, 2):
		var coord = Vector2i(15, i + 5)
		var sock = xNetVerts.xSocket.new()
		sock.mode = xNetVerts.xSocket.INPUT
		net.get_or_add_vert(coord, sock)
	for i in range(0, 20, 2):
		var coord = Vector2i(16, i + 6)
		var sock = xNetVerts.xSocket.new()
		sock.mode = xNetVerts.xSocket.OUTPUT
		net.get_or_add_vert(coord, sock)

func _mouse_over_joint(where:Vector2):
	var cell = to_grid(where)
	coord_joint = cell
	sel_vert = net.netlist.vias.get(cell, null)

func _mouse_over_wire(where:Vector2):
	for pair in net.netlist.links:
		var joints = net.netlist.pairs[pair]
		var wire = net.netlist.links[pair]
		sel_wire = wire.near(where, wire.get_verts(from_grid(joints[0].coord), from_grid(joints[1].coord)))
		if not sel_wire.is_empty():
			sel_wire["pair_hash"] = pair
			sel_wire["bend"] = wire.bend
			break

func _resize_bend(ini_pos:Vector2, end_pos:Vector2):
		var ini_bend : float = sel_wire.bend
		var delta = end_pos - ini_pos
		
		var wire : xNetBase.xWire = net.netlist.links.get(sel_wire.pair_hash)
		var joints = net.netlist.pairs[sel_wire.pair_hash]
		var diff = from_grid(joints[0].coord - joints[1].coord)
		var diff_abs = diff.abs()
		var short_axis = diff_abs.min_axis_index()
		var shortest = diff_abs[short_axis]
		var dir = 1 if diff[short_axis] > 0 else -1
		
		delta = delta.length() * -delta.sign()[short_axis] * dir * 2
		wire.bend = clamp(ini_bend + delta, CELL_DIA, shortest)


func _splice_wire() -> xNetVerts.xJoint:
	var new_joint := xNetVerts.xJoint.new()
	var wire : xNetBase.xWire = net.netlist.links.get(sel_wire.pair_hash)
	var joints = net.netlist.pairs[sel_wire.pair_hash]
	var where = wire.position_along(sel_wire.ratio, from_grid(joints[0].coord), from_grid(joints[1].coord))
	new_joint.coord = to_grid(where)
	new_joint = net.get_or_add_vert(new_joint.coord, new_joint) as xNetVerts.xJoint
	net.rem_link_verts(joints[0], joints[1])
	net.make_link(joints[0], new_joint, wire)
	net.make_link(new_joint, joints[1], wire.duplicate())
	sel_wire.clear()
	return new_joint


func _on_drag_threshold(left:bool, _right:bool):
	if not sel_wire.is_empty() and left:
		if floori(sel_wire.subratio) != 1:
			sel_vert = _splice_wire()


var start_drag : Vector2
var was_drag : bool
var past_threshold : bool
func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.is_echo():
		#FIXME Not getting key inputs!
		match event.keycode:
			KEY_DELETE:
				if event.is_released():
					queue_redraw()
					if sel_vert != null and not sel_vert is xNetVerts.xSocket:
						net.rem_vert(sel_vert)
					elif not sel_wire.is_empty():
						net.rem_link_hash(sel_wire.pair_hash)
			KEY_ESCAPE:
				if event.is_released():
					if was_drag and not sel_wire.is_empty():
						# Delete wire being pulled.
						pass
	
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			was_drag = true
			if not sel_wire.is_empty():
				if abs((start_drag - event.position).length()) > CELL_DIA and not past_threshold:
					past_threshold = true
					_on_drag_threshold(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
				elif floori(sel_wire.subratio) == 1:
					_resize_bend(start_drag, event.position)
					queue_redraw()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			if sel_vert != null:
				queue_redraw()
	
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if event.is_pressed():
			queue_redraw()
			start_drag = event.position
			_mouse_over_joint(event.position)
			if sel_vert == null:
				_mouse_over_wire(event.position)
			else:
				sel_wire.clear()
			
		elif event.is_released():
			if was_drag:
				was_drag = false
				past_threshold = false
				queue_redraw()
				var cell = to_grid(event.position)
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						# Create Wire
						var orig_joint = sel_vert
						if orig_joint != null:
							_mouse_over_joint(event.position)
							if sel_vert == null:
								_mouse_over_wire(event.position)
							if sel_wire.is_empty() or floori(sel_wire.subratio) == 1:
								sel_vert = net.get_or_add_vert(cell, xNetVerts.xJoint.new())
							else:
								sel_vert = _splice_wire()
							var wire = xNetBase.xWire.from_len(orig_joint.coord, sel_vert.coord, Input.is_key_pressed(KEY_SHIFT))
							wire.bend = CELL_DIA
							
							net.make_link(orig_joint, sel_vert, wire)
					MOUSE_BUTTON_RIGHT:
						# Move Joint
						if sel_vert != null and not sel_vert is xNetVerts.xSocket:
							if not net.netlist.vias.has(cell):
								net.netlist.vias.erase(coord_joint)
								net.netlist.vias[cell] = sel_vert
								sel_vert.coord = cell

func _draw() -> void:
	# Draw stuff on the netlist
	for pair in net.netlist.links:
		var joints = net.netlist.pairs[pair]
		var wire = net.netlist.links[pair]
		wire.draw(self, from_grid(joints[0].coord), from_grid(joints[1].coord), sel_wire.get("pair_hash", 0) == pair)
	for id in net.netlist.verts:
		var vert = net.netlist.verts[id]
		if vert == sel_vert and was_drag and not vert is xNetVerts.xSocket: continue
		vert.draw(self, from_grid(vert.coord), sel_vert == vert)
