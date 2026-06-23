@abstract
extends RefCounted
class_name xNetConnect

## An abstract class for things that can be connected in a network, like sockets
## and wires.

var wire : xNetwork.xWire

@abstract func get_rect() -> Rect2

## Find all things that connect directly with this object.
@abstract func get_connections() -> Array[xNetConnect]

## Returns something if the [code]point[/code] is near this object.
@abstract func near(point:Vector2) -> Variant

## How to draw this object on the [code]canvas[/code].
@abstract func draw(canvas:Control, highlight:bool=false)
