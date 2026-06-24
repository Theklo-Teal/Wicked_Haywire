extends xNetConnect
class_name xSocket

## Anchors to world coordinate for Segments
var layer : StringName
var tunnel : StringName
var position: Vector2

func _init(where:Vector2):
	position = where
func get_port() -> xNetwork.xPort:
	if wire == null:
		return null
	return wire.get_port()

func get_rect() -> Rect2:
	var size = Vector2(0.4, 0.4) * X.CELL_DIA
	return Rect2(position - size, size)

func get_connections() -> Array[xNetConnect]:
	if wire == null: return []
	var conns : Array[xNetConnect]
	conns.assign(wire.segms)
	return conns

func near(point:Vector2) -> bool:
	return get_rect().has_point(point)

func draw(canvas:Control, highlight:=false):
	var thick = (X.CELL_RAD - X.VIA_RAD) # Find the thickness that produces a hole of constant size.
	var clr : Color = Color.YELLOW if highlight else Color.GOLDENROD
	canvas.draw_circle(position, X.CELL_RAD - thick / 2.0 - X.CLEARANCE, clr, false, thick)


#region Simulation Fuctions
func emit(val):
	var port = get_port()
	if port != null:
		port.write(val)

func query():
	var port = get_port()
	if port == null:
		return xNetwork.xPort.default
	else:
		return port.read()

## Called during simulation update. Override this to call on [code]emit()[/code]
## and [code]query()[code] as necessary.
func prompt():
	return
#endregion
