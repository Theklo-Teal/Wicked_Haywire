extends xNetwork.xNetConnect
class_name xJoint

## Basic class for nodes in a xNetwork graph. From which specialized sockets are extended.
## It also serves a world anchor to xWire and possesses a Dijkstra node.

var port : xNetwork.xPort

func _init():
	super()

## Produce a Rect2 from world space position.
func get_rect():
	var size = Vector2.ONE * X.CELL_DIA
	return Rect2(position - size / 2.0, size)
## Produce a Rect2 from a coordinate on the grid.
func get_grid_rect(coord:Vector2i) -> Rect2:
	position = X.from_grid(coord)
	return get_rect()

func draw(canvas:Control, highlight:=false):
	if dijkstra.wired.size() != 2:
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
