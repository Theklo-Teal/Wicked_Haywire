extends RefCounted
class_name xNetwork

## A network is composed of netlists which are isolated graphs. sockets are
## connected by Wires and wires refer to a Port where sockets emit to or receive
## signals from. Ports shared between Wires mean they have a tunnel between them.

#TODO Make mouse hover cell match proper position of staggered cells.
#TODO Ensure no wires are created where there is already a connection.
#TODO Wire deletion
#TODO Wire detach
#TODO Wire split
#TODO Wire join
#TODO Chamfer adjust by dragging
#TODO Wire shifting (Soon:tm:)
#TODO Wire merge (Soon:tm:)
#TODO Port management with wires. (Network merge and join)

var sockets : Dictionary[Vector2i, xSocket]  ## Being in a dictionary of position, we can be sure sockets don't overlap.
var list : Dictionary[xWire, xPort]  ## Isolated graphs and the signal ports associated. If [code]Port[/code] is null, the graph needs updating.

#region Get things
func get_Port(wire:xWire) -> xPort:
	return list.get(wire)
func get_Wire(port:xPort) -> Array[xWire]:
	var found : Array[xWire]
	for each in list:
		if list[each] == port:
			found.append(each)
	return found

## Returns an existing socket or [code]null[/code] if there's none at that coordinate.
func get_socket(where:Vector2) -> xSocket:
	var coords = X.to_grid(where)
	return sockets.get(coords.cell_coord)
#endregion
#region Add Things
## Returns an existing socket or creates one if it doesn't exist at the coordinate.
func add_socket(where:Vector2) -> xSocket:
	var coords = X.to_grid(where)
	var sock : xSocket = sockets.get_or_add(coords.cell_coord, xSocket.new(coords.cell_position))
	return sock

func add_wire_segm(from:xSocket, to:xSocket, short_first:bool=false) -> xWireSegm:
	var wire : xWire = from.wire
	if wire == null:
		wire = to.wire
	if wire == null:
		wire = xWire.new()
		from.wire = wire
		to.wire = wire
		list[wire] = xPort.new()
	else:
		from.wire = wire
	
	var segm = xWireSegm.from_length(from.position, to.position, short_first)
	segm.wire = wire
	wire.segms.append(segm)
	wire.rect = wire.rect.merge(segm.get_rect())
	return segm
#endregion
#region Remove Things
func delete_sock(s:xSocket) -> Error:
	var cell = sockets.find_key(s)
	sockets.erase(cell)
	return OK

func delete_segm(w:xWire, s:xWireSegm) -> Error:
	## Removes a wire segment from this wire. If the segment isn't found, returns
	## [code]ERR_DOES_NOT_EXIST[/code]. If the wire runs out of segments, it returns
	## [code]ERR_TIMEOUT[/code] and deletes its [code]Port[/code] as a sign to
	## update and eventual deletion of the wire itself.
	if not s in w.segms:
		return ERR_DOES_NOT_EXIST
	w.segms.erase(s)
	if w.segms.is_empty():
		# Mark for deletion of the wire in the network.
		list[w] = null
		return ERR_TIMEOUT
	return OK
#endregion

#region Graph Stuff
class xWire:
	var rect : Rect2
	var layer : StringName
	var segms : Array[xWireSegm]
	
	func draw(canvas:Control, selected:xWireSegm):
		for each in segms:
			each.draw(canvas, each == selected)
	
	## Returns a list of segments which [code]xWireSegm.rect[/code] contains [code]point[/code].[br]
	## Returns empty if the point is outside this Wire's [code]rect[/code].
	func find_segment(point:Vector2) -> Array[xWireSegm]:
		#NOTE we grow the rects, because the drawn line is split lengthwise,
		# where half of it is outside the rect. We want the user to be able to
		# select by clicking anywhere on the visible line.
		var matches : Array[xWireSegm]
		if not rect.grow(X.CELL_RAD).has_point(point):
			return []
		for segm in segms:
			if segm.get_rect().grow(X.CELL_RAD).has_point(point):
				matches.append(segm)
		return matches
#endregion

#region Simulation Stuff
func setup_cycle():
	pass
func cycle_update():
	for cell in sockets:
		var sock = sockets[cell]
		sock.prompt()
func finish_cycle():
	pass

class xPort:
	var value
	var aggregate : Array
	
	## If the port has no values feeding in, what should it be read as?
	static func default():
		return 0
	func integrate():
		value = aggregate.reduce(func(sum, a):return sum + a, 0)
	func read():
		return value
	func write(val):
		aggregate.append(val)
#endregion
