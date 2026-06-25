extends RefCounted
class_name Dijkstra

## A basic pathfinding class that finds the path in a graph.
## It finds the smallest number of connections towards the closest target or endpoint.
## It can have many targets, so it seeks the closest one to a given node.[br]
## Anything considered a node of the graph must extend [code]Dijkstra.DijkstraNode[/code].

#TODO implement node exclusion

@abstract class DijkstraNode:
	var dijkstra_timestamp : int = 0  ## The time a mapping search started. If this timestamp is found outdated, we reset [code]dijkstra[/code].
	var dijkstra : int = 0  ## Minimum connections towards the closest target. Negative value means we don't know yet.
	var dijkstra_exclude := false  ## Not implemented. Refuse any connections to this node.
	
	## The nodes that connect away from node and how much it cost to travel there.[br]
	## In non-directed graphs, two connected nodes reference each other, but that
	## may not be the case, so some connections are directed in a single way.[br]
	## You may also decide according to the [code]origin[/code] of a network search.
	@abstract func get_dijkstra_connections(origin:DijkstraNode) -> Dictionary[DijkstraNode, int]
	
	## Define whether this node counts as an end point on the graph.[br]
	## You might return [code]true[/code] if this node has reference to some
	## object of interest that isn't another DijkstraNode.
	@abstract func is_dijkstra_target() -> bool
	
	## By default just returns a basic network, but you may want to provide a
	## different class inheriting [code]DijkstraQuery[/code] with different
	## search rules.
	func new_dijkstra_network() -> DijkstraQuery:
		return DijkstraQuery.new(self)

class DijkstraQuery:
	
	## An helper class to independently track search from different targets.[br]
	## It can be extended to make different iteration or search rules.
	
	var head : int = 0  ## How far into the queue have we checked nodes.
	var queue : Array[DijkstraNode]  ## All nodes found.
	var targets : Array[DijkstraNode]  ## Target nodes found to connect with the origin.
	
	func _init(origin:DijkstraNode):
		origin.dijkstra = 0
		queue.append(origin)
	
	## Define whether a given object counts as an end point on the graph.[br]
	## By default it returns false if the object isn't a DijkstraNode, otherwise
	## asks the object whether they are a target.[br]
	## You might return [code]true[/code] if this node has reference to some object
	## of interest that isn't another DijkstraNode.
	func is_dijkstra_target(object) -> bool:
		if object is DijkstraNode:
			return object.is_dijkstra_target()
		else:
			return false
	
	func is_finished() -> bool:
		return head >= queue.size()
	
	func _sorted_pairs(dict:Dictionary, by_value:=true) -> Array[Array]:
		var pairs : Array[Array]
		for k in dict:
			pairs.append([k, dict[k]])
		pairs.sort_custom(func(a,b): return a[by_value as int] > b[by_value as int])
		return pairs
	
	## Performs cost calculation and returns any other targets found.[br]
	## Target nodes found that are not origin will be stored in
	## [code]DijkstraQuery.targets[/code]. This allows to find isolated networks.[br]
	## Returns novel targets that weren't initially known.
	func iterate(timestamp:int, known_targets:Array[DijkstraNode]) -> Array[DijkstraNode]:
		if head >= queue.size():
			printerr("Dijkstra.DijskstraQuery.iterate(): Queue Overflow!")
			return []
		var curr : DijkstraNode = queue[head]
		head += 1
		var naibaro = _sorted_pairs(curr.get_dijkstra_connections(queue[0]))
		var endpoints : Array[DijkstraNode]
		for pair in naibaro:
			var node : DijkstraNode = pair[0]
			var cost : int = pair[1]
			if not node in queue:
				queue.append(node)
			if node.dijkstra_timestamp != timestamp:
				# The node has never been visited in the current mapping operation.
				node.dijkstra = -1
				node.dijkstra_timestamp = timestamp
			var next_cost = curr.dijkstra + cost
			if is_dijkstra_target(node):
				if node not in targets:
					targets.append(node)
				if not (node in endpoints or node in known_targets):
					endpoints.append(node)
			else:
				if node.dijkstra < 0:
					node.dijkstra = next_cost
				node.dijkstra = min(node.dijkstra, next_cost)
		return endpoints


## Run a search from all known targets to calculate the travel cost of any
## found nodes in between.[br]
## Any targets discovered along the way initiate further searches.
## Returns an array of all [code]DijkstraQuery[/code] generated.
## Each one with lists of nodes and endpoints they've found.
func dijkstra_mapping(targets:Array[DijkstraNode]) -> Array[DijkstraQuery]:
	var timestamp : int = Time.get_ticks_usec()
	
	var networks : Dictionary[DijkstraNode, DijkstraQuery]
	for each in targets:
		networks[each] = each.new_dijkstra_network()
		each.dijkstra = 0
		each.dijkstra_timestamp = timestamp
	
	var finished : int = 0
	var head : int = 0  ## index of current network being searched
	while finished < networks.size():
		# Iterate alternatingly through all networks
		var curr : DijkstraQuery = networks.values()[head]
		head = wrapi(head + 1, 0, networks.size())
		if curr.is_finished():
			continue
		for found in curr.iterate(timestamp, targets):
			if not found in networks:
				networks[found] = found.new_dijkstra_network()
				found.dijkstra = 0
				found.dijkstra_timestamp = timestamp
		if curr.is_finished(): finished += 1;
		
	return networks.values()


## After computing travel costs of nodes with [code]dijkstra_mapping[/code],
## this returns the nodes from [code]origin[/code] along the way with the least
## cost until a target is found. A target is defined as a node with
## [code]dijkstra[/code] cost of zero.[br]
## It returns the path found to the target. If can't be found returns partial
## path, if told to.[br]
## The [code]path[/code] will avoid nodes with [code]DijkstraNode.dijkstra_blocked[/code]
## set to [code]true[/code]. If [origin] is blocked, that doesn't affect outcome.
func dijkstra_search(origin:DijkstraNode, partial:=false) -> Array[DijkstraNode]:
	var curr : DijkstraNode = origin
	var path : Array[DijkstraNode] = [origin]
	while path.back().dijkstra != 0:
		var naibaro = curr.get_dijkstra_connections(origin).keys()
		naibaro = naibaro.filter( func(a): return not a.dijkstra < 0 )
		if naibaro.size() == 0:
			# Nowhere to go, return with partial solution.
			break
		naibaro.sort_custom(func(a, b): return a.dijkstra < b.dijkstra)
		path.append(naibaro[0])
		curr = naibaro[0]
	if path.back().dijkstra != 0 and not partial:
		return []
	return path
