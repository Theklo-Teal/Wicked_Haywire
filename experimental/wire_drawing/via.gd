extends xJoint
class_name xVia

var name : StringName  ## Vias of the same name are considered connected

func _init():
	super()
	dijkstra.is_target = true

func draw(canvas:Control, position:Vector2, highlight:=false):
	var thick = (X.CELL_RAD - X.VIA_RAD) # Find the thickness that produces a hole of constant size.
	var clr : Color = Color.YELLOW if highlight else Color.GOLDENROD
	canvas.draw_circle(position, X.CELL_RAD - thick / 2.0 - X.CLEARANCE, clr, false, thick)
