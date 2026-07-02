extends xNetwork.xJoint
class_name xSocket

enum {
	HIZ,  ## Socket electrically disconnected, reading as very high resistivity.
	INPUT,  ## Socket that only receives signals.
	OUTPUT,  ## Socket that only transmits signals.
	BIDIR,  ## Socket that's passive, relaying whatever it receives, like a Bus connector.
}

@export_enum("HIZ INPUT OUTPUT BIDIR",) var mode : int


func draw(canvas:Control, highlight:=false):
	var rect = get_rect()
	var clr : Color = Color.YELLOW if highlight else Color.GOLDENROD
	match mode:
		INPUT:
			canvas.draw_circle(position, X.CELL_RAD, clr)
		OUTPUT:
			rect = rect.grow(-X.CLEARANCE / 2.0)
			canvas.draw_rect(rect, clr)
		HIZ:
			var corn = [rect.position, Vector2(rect.postion.x, rect.end.y), Vector2(rect.end.x, rect.postion.y), rect.end]
			canvas.draw_multiline([corn[0], corn[3], corn[1], corn[2]], clr, 3)
		BIDIR:
			rect = rect.grow(-X.CLEARANCE  / 2.0)
			canvas.draw_rect(rect, clr, false, 2)
			canvas.draw_circle(position, X.CELL_RAD, clr, false, 2)

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
