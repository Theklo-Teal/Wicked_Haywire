extends xNetwork.xJoint
class_name xSocket

enum {
	HIZ,  ## Socket electrically disconnected, reading as very high resistivity.
	INPUT,  ## Socket that only receives signals.
	OUTPUT,  ## Socket that only transmits signals.
	BIDIR,  ## Socket that's passive, relaying whatever it receives, like a Bus connector.
}

@export_enum("HIZ INPUT OUTPUT BIDIR",) var mode : int


func draw(canvas:Control, highlight:bool=false):
	match mode:
		INPUT:
			canvas.draw_circle(position, X.CELL_RAD, colors[1] if highlight else colors[2])
		OUTPUT:
			var rect = Rect2(position - Vector2.ONE * X.CELL_RAD, Vector2.ONE * X.CELL_DIA).grow(-X.CLEARANCE / 2.0)
			canvas.draw_rect(rect, colors[1] if highlight else colors[2])
	
	draw_wires(canvas)
