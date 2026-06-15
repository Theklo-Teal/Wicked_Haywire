extends FlowchartGraph
class_name FlowchartGraphElectronics

class LinkDigital extends Link:
	var max_value : int = 0b1111 : 
		set(val):
			max_value = max(1, val) 
			bitwidth = floori(log(max_value) / log(2) + 1)
			max_value = (1 << bitwidth) - 1
	var bitwidth : int = 4 :  # How many wires are carrying the value.
		set(val):
			bitwidth = max(0, val)
			max_value = (1 << bitwidth) - 1
	
	var pulled_up : int : # Mask of bits which are biased high if floating.
		set(val):
			pulled_up = val
			pulled_dn ^= pulled_up
	var pulled_dn : int :  # Mask of bits which are biased low if floating.
		set(val):
			pulled_dn = val
			pulled_up ^= pulled_dn
	
	static func unconnected_default():
		return 0
	func _get_default():
		return randi_range(0, max_value)
			
	func _init() -> void:
		randomize()
	
	# This randomizes the bits which are in conflict (more than one source trying to write it) and which are at hi-z.
	func integrate():
		if aggregate.size() == 0:
			value["floating"] = max_value
			value["conflict"] = 0
		var ans : Dictionary = {
			"val": 0,
			"floating": max_value,  # Bits that aren't powered.
			"conflict": 0,  # Bits with multiple sources writing to it.
			}
		
		for each in aggregate:
			ans.floating &= each.hiz
		var noisy = max_value ^ (pulled_up | pulled_dn) | ans.conflict
		ans |= ans.floating & pulled_up
		ans |= ans.floating & pulled_dn
		ans |= noisy & randi_range(0, max_value)
		
		return ans
	
	func write_filter(val):
		return {"val": val.val & max_value, "hiz": val.hiz & max_value}
	
	func read_filter():
		var reverse_mask = max_value ^ value.hiz
		var noisy_bits = randi_range(0, max_value) & value.hiz
		var meaningful_bits = value.val & reverse_mask
		return {"val": meaningful_bits | noisy_bits, "hiz": value.hiz}
