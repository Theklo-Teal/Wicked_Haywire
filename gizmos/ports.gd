extends RefCounted
class_name PORT

class Digital extends NetBase.Port:
	@export_storage var bitwidth : int = 1 : 
		set(val):
			bitwidth = clamp(val, 1, 32)
	
	static func default_link():
		return &"BitWire"
