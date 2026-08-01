extends RefCounted
class_name xNetVerts

## Example implementations of NetBase.NetVert.

class xJoint extends xNetBase.xNetVert:
	## A NetVert that joints Wires together, allowing to compose a path.
	
	func draw(canvas:Control, position:Vector2, highlighted:=false):
		var color = colors[1] if highlighted else colors[2]
		canvas.draw_circle(position, xGraphDraw.CELL_DIA / 3.0, color, false, 5)

class xSocket extends xJoint:
	## A special NetVert that can't be deleted or edited.
	
	enum {
		HIZ,  ## Socket electrically disconnected, reading as very high resistivity.
		INPUT,  ## Socket that only receives signals.
		OUTPUT,  ## Socket that only transmits signals.
		BIDIR,  ## Socket that's passive, relaying whatever it receives, like a Bus connector.
	}
	@export_enum("HIZ INPUT OUTPUT BIDIR",) var mode : int

	func draw(canvas:Control, position:Vector2, highlighted:=false):
		var color = colors[1] if highlighted else colors[2]
		match mode:
			INPUT:
				canvas.draw_circle(position, xGraphDraw.CELL_DIA / 2.0, color)
			OUTPUT:
				var rect = Rect2(position - Vector2.ONE * xGraphDraw.CELL_DIA / 2.0, Vector2.ONE * xGraphDraw.CELL_DIA)
				canvas.draw_rect(rect, color)
