extends Resource
class_name xJoint

## Basic class for nodes in a xNetwork graph. From which specialized sockets are extended.
## It also serves a world anchor to xWire and possesses a Dijkstra node.

@export var dijkstra : xNetwork.xNetNode
var port : xNetwork.xPort

func _init():
	dijkstra = xNetwork.xNetNode.new(self)

## Connect the to other xJoint, optionally using an existing wire, otherwise
## a new one is created. The wire used is returned.
func connect_to(other:xJoint, use_wire:xWire=null) -> xWire:
	if use_wire == null:
		use_wire = xWire.from_chiral(self, other, true)
	other.dijkstra.wires.append(use_wire)
	return use_wire

## Disconnect from a wire shared with [code]other[/code]. Both this xJoint and
## the other's will have that wire reference removed. One way wires will also
## be removed.[br]
## The wire is returned for further processing or [code]null[/code]
## if connection doesn't exist.
func disconnect_to(other:xJoint) -> xWire:
	for wire in dijkstra.wires:
		var conns = [wire.ori_conn, wire.end_conn]
		if self in conns and other in conns:
			dijkstra.wires.erase(wire)
			other.wires.erase(wire)
			wire.ori_conn = null
			wire.end_conn = null
			return wire
	for wire in other.dijkstra.wires:
		var conns = [wire.ori_conn, wire.end_conn]
		if self in conns and other in conns:
			dijkstra.wires.erase(wire)
			other.wires.erase(wire)
			wire.ori_conn = null
			wire.end_conn = null
			return wire
	return null

## Produce a Rect2 from world space position.
func get_rect(position:Vector2):
	var size = Vector2.ONE * X.CELL_DIA
	return Rect2(position - size / 2.0, size)
## Produce a Rect2 from a coordinate on the grid.
func get_grid_rect(coord:Vector2i) -> Rect2:
	return get_rect(X.from_grid(coord))

func draw(canvas:Control, position:Vector2, highlight:=false):
	if dijkstra.wires.size() != 2:
		var clr : Color = Color.YELLOW if highlight else Color.GOLDENROD
		canvas.draw_circle(position, X.CELL_RAD, clr)


#region Simulation Fuctions
#func emit(val):
	#var port = get_port()
	#if port != null:
		#port.write(val)
#
#func query():
	#var port = get_port()
	#if port == null:
		#return xNetwork.xPort.default
	#else:
		#return port.read()

## Called during simulation update. Override this to call to [code]emit()[/code]
## and [code]query()[code] as necessary.
#func prompt():
#	return
#endregion
