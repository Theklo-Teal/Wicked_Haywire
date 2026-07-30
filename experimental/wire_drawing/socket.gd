extends xNetwork.xJoint
class_name xSocket

enum {
	HIZ,  ## Socket electrically disconnected, reading as very high resistivity.
	INPUT,  ## Socket that only receives signals.
	OUTPUT,  ## Socket that only transmits signals.
	BIDIR,  ## Socket that's passive, relaying whatever it receives, like a Bus connector.
}

@export_enum("HIZ INPUT OUTPUT BIDIR",) var mode : int


func draw(canvas:Control):
	match mode:
		INPUT:
			canvas.draw_circle(X.from_grid(coord), X.CELL_RAD, colors[1])
		OUTPUT:
			var rect = Rect2(X.from_grid(coord) - Vector2.ONE * X.CELL_RAD, Vector2.ONE * X.CELL_DIA).grow(-X.CLEARANCE / 2.0)
			canvas.draw_rect(rect, colors[1])
