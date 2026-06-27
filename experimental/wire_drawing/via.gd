extends xJoint
class_name xVia

## A simple xJoint that isn't associated with Gizmos and to be used
## as the ending of a wire and labelled to create a tunnel connection.

var name : StringName  ## Vias of the same name are considered connected

func draw(canvas:Control, highlight:=false):
	var thick = (X.CELL_RAD - X.VIA_RAD) # Find the thickness that produces a hole of constant size.
	var clr : Color = Color.YELLOW if highlight else Color.GOLDENROD
	canvas.draw_circle(position, X.CELL_RAD - thick / 2.0 - X.CLEARANCE, clr, false, thick)
