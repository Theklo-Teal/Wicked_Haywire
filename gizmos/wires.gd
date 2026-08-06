extends RefCounted
class_name WIRES

class BitWire extends NetBase.Link:
	static func _wire_thick() -> int:
		return floori(Flowchart.JOINT_RAD * 0.7)

class BitCable extends BitWire:
	static func _wire_thick() -> int:
		return floori(Flowchart.SNAP * 0.7)
