@abstract
extends Dijkstra.DijkstraNode
class_name xNetConnect

## An abstract class for things that can be connected in a network, like sockets
## and wires.
 
@abstract func get_rect() -> Rect2

## Returns something if the [code]point[/code] is near this object.
@abstract func near(point:Vector2) -> Variant

## How to draw this object on the [code]canvas[/code].
@abstract func draw(canvas:Control, highlight:bool=false)
