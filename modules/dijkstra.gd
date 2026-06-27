extends RefCounted
class_name Dijkstra

## A basic pathfinding class that finds the path in a network. It does this by setting a
## [code]cost[/code] value of travel on each [code]DijkstraNode[/code]. By default
## the travel cost is the smallest number of connections towards the closest target
## or endpoint. Many targets are allowed.[br]
## The cost can be influenced by setting a [code]weight[/code] to each nodes,
## which then changes the interpretation of the cost value.

class DijkstraNode extends Resource:
	## Encapsulated data for node in a graph. This could be better implement if there
	## was "traits" programming feature.[br]
	## Each object representing a node in a network, should hold an instance of this
	## class. Any pathfinding operation will either read or modify this instance.[br]
	## This class can be extended to affect things like [code]weight[/code] or
	## how connections are found.
	
	var timestamp : int = 0  ## [code]Time.get_ticks_usec()[/code] at the moment of map updating. Allows telling if node is outdated.
	@export var exclude := false  ## Whether to refuse connections to this node. [code]Dijkstra.mapping()[/code] must be called for changes to take effect. Prefer using [code]set_enabled()[/code].
	@export var cost : int = 0  ## Cost of travelling from this node to the closest endpoint.
	@export var weight : int = 1 ## Cost of connecting to this node
	@export var is_target := false  ## Whether this is an endpoint of the graph.
	@export var connected : Array[DijkstraNode]  ## List of nodes, representing a one-way connection with them.
	
	## The returned [code]DijkstraNode[/code] includes a metadata key
	## [code]dijkstra_node_owner[/code] of key [code]owner[/code]. That object
	## represents something in a graph.
	func _init(owner:Object) -> void:
		set_meta("dijkstra_node_owner", owner)
		cost = 0 if is_target else -1
	
	## Connect to [code]other_node[/code].
	func connect_node(other_node:DijkstraNode, bidirectional:=false):
		if not other_node in connected:
			connected.append(other_node)
			if bidirectional:
				other_node.connect_node(self)
	
	## Disconnect from [code]other_node[/code]. If [code]bidirectional[/code] is true,
	## even if connection doesn't exist to [code]other_node[/code], it will remove
	## connection from it.
	func disconnect_node(other_node:DijkstraNode, bidirectional:=false):
		connected.erase(other_node)
		if bidirectional:
			other_node.disconnect_node(self)
	
	## Recompute the graph map with this node included or excluded.[br]
	## This fuction might not take effect depending on implementation of
	## [code]refuse_connection()[/code].[br]
	## For setting many nodes at once, call [code]Dijkstra.node_exclusion()[/code].
	func set_enabled(enabled:=false):
		exclude = not enabled
	
	## Whether to refuse connecting from [code]source_node[/code].[br]
	## By default relays [code]exclude[/code], effectively refusing all connections
	## if set to [code]true[/code].
	@warning_ignore("unused_parameter")
	func refuse_connection(source_node:DijkstraNode) -> bool:
		return exclude
	
	## The cost of the connection from [code]source_node[/code] to this one.
	@warning_ignore("unused_parameter")
	func get_weight(source_node:DijkstraNode) -> int:
		return weight
	
	## By default returns [code]connected[/code], but can be overriden for more
	## complex behavior.
	@warning_ignore("unused_parameter")
	func get_connections(source_node:DijkstraNode) -> Array[DijkstraNode]:
		return connected
	
	## If a node owner contains the method [code]dijkstra_mapped[/code], that
	## will be called when a mapping operation is finished and the node of
	## that owner was involved.
	func _graphs_mapped():
		var owner : Object = get_meta("dijkstra_node_owner")
		if owner != null and owner.has_method("dijkstra_mapped"):
			owner.dijkstra_mapped()
		graphs_mapped()
	## What to do when this node was found while mapping a network
	## and the mapping is finished?
	func graphs_mapped():
		pass
	
	## If [code]is_target[/code] is [code]true[/code], this function is used to
	## return a search query object. This can be overriden to use extensions of 
	## [code]DijkstraQuery[/code].
	func new_query() -> DijkstraQuery:
		return DijkstraQuery.new(self)


class DijkstraQuery:
	## An helper class to independently track search from different targets.[br]
	## It can be extended to make different iteration or search rules.
	
	var head : int = 0  ## How far into the queue have we checked nodes.
	var queue : Array[DijkstraNode]  ## All nodes found.
	var endpoints : Array[DijkstraNode]  ## Target nodes found to connect with the origin.
	
	func _init(origin:DijkstraNode):
		origin.cost = 0
		queue.append(origin)
	
	## Define whether a given object counts as an end point on the graph.[br]
	## By default it returns false if the object isn't a DijkstraNode, otherwise
	## asks the object whether they are a target.[br]
	## You might return [code]true[/code] if this node has reference to some object
	## of interest that isn't another DijkstraNode.
	func is_target(object) -> bool:
		if object is DijkstraNode:
			return object.is_target()
		else:
			return false
	
	func is_finished() -> bool:
		return head >= queue.size()
	
	func graphs_mapped():
		for each in queue:
			each.graphs_mapped()
	
	## Performs cost calculation and returns any other targets found.[br]
	## Target nodes found that are not origin will be stored in
	## [code]DijkstraQuery.endpoints[/code]. This allows to find isolated networks.[br]
	## Returns novel targets that weren't initially known.
	func iterate(timestamp:int, past_targets:Array[DijkstraNode]) -> Array[DijkstraNode]:
		if head >= queue.size():
			printerr("Dijkstra.DijskstraQuery.iterate(): Queue Overflow!")
			return []
		var curr : DijkstraNode = queue[head]
		head += 1
		var naibaro = curr.get_connections(queue[0])
		naibaro = naibaro.filter(func(a): return not a[0].refuse_connection(curr))
		var novels : Array[DijkstraNode]
		for node in naibaro:
			if not node in queue:
				queue.append(node)
			if node.timestamp != timestamp:
				# The node has never been visited in the current mapping operation.
				node.cost = -1
				node.timestamp = timestamp
			var next_cost = curr.cost + node.get_weight(curr)
			if node.is_target:
				if node not in endpoints:
					endpoints.append(node)
				if not (node in novels or node in past_targets):
					novels.append(node)
			else:
				if node.cost < 0:
					node.cost = next_cost
				node.cost = min(node.cost, next_cost)
		return novels


## Set whether the given nodes are to be excluded from navigation and updates the map.
func node_exclusion(exclude:bool, ...node):
	for each in node:
		if not each is DijkstraNode:
			printerr("Dijkstra.node_exclusion(): Not a DijkstraNode!")
			continue
		node.exclude = exclude
	mapping()

## Something to do when a mapping operation is finished.[br]
## By default it calls similar methods in the given [code]queries[/code].
func graphs_mapped(queries:Array[DijkstraQuery]):
	for each in queries:
		each.graph_mapped()

var past_targets : Array[DijkstraNode]  ## We keep track of targets used and found in the last iteration, such as we can repeat the same search in the future with hindsight of discoveries.
## Run a search from all given targets to calculate the travel cost of any
## found nodes in between.[br]
## If no target is given, it searches from target nodes found on a past call.[br]
## Any targets discovered along the way initiate further searches.
## Returns an array of all [code]DijkstraQuery[/code] generated.
## Each one with lists of nodes and endpoints they've found.
func mapping(...targets) -> Array[DijkstraQuery]:
	var timestamp : int = Time.get_ticks_usec()
	var networks : Dictionary[DijkstraNode, DijkstraQuery]
	
	if targets.is_empty():
		for each : DijkstraNode in past_targets:
			if each.get_reference_count() > 1:
				# If the only reference to this node is in this list,
				# it means it was meant to be deleted.
				targets.append(each)
	for each in targets:
		if not each is DijkstraNode:
			printerr("Dijkstra.mapping(): Not a DijkstraNode!")
			continue
		networks[each] = each.new_dijkstra_network()
		each.cost = 0
		each.timestamp = timestamp
	past_targets.assign(targets)
	
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
				# Discovered an unmentioned target
				networks[found] = found.new_query()
				past_targets.append(found)
				found.cost = 0
				found.timestamp = timestamp
		if curr.is_finished(): finished += 1;
	graphs_mapped(networks.values())
	return networks.values()


## After computing travel costs of nodes with [code]mapping()[/code],
## this returns the owners of nodes from [code]origin[/code] along the way with 
## the least cost until a target is found. 
## If nodes have no owner in their metadata, we return the node itself.[br]
## The order of returned objects follows the path found to the target.
## If can't be found returns partial path, if told to.[br]
## Nodes that refuse connection will be avoided. The [code]origin[/code] node 
## is not affected by this.[br]
## If [code]jitter[/code] is set [code]true[/code] randomly picks nodes with the
## same cost, potentially eliminating bias.
static func search(origin:DijkstraNode, partial:=false, jitter:=false) -> Array:
	var curr : DijkstraNode = origin
	var path : Array[DijkstraNode] = [origin]
	var options : Array[DijkstraNode]
	while not path.back().is_target:
		var naibaro = curr.get_connections(origin)
		naibaro = naibaro.filter( func(a): return not a.cost < 0 )
		if naibaro.size() == 0:
			curr = options.pop_back()
			if curr == null:
				# Nowhere to go, return with partial solution.
				break
			# Backtrack and attempt an alternate path.
			continue
		naibaro.sort_custom(func(a, b): return a.cost > b.cost)
		naibaro = naibaro.filter( func(a): return a.cost == naibaro[-1].cost )  # Select all nodes with the same cost.
		curr = naibaro.pop_at(randi() % naibaro.size() if jitter else -1)
		options.append_array(naibaro)
	
	if not (path.back().is_target or partial):
		# The last node is not a target and we don't want partial paths.
		return []
	
	var path_owners : Array
	for node in path:
		path_owners.append( node.get_meta("dijkstra_node_owner", node) )
	return path_owners

## Cause propagation of a function call to all owners of nodes in the same
## graph as [code]endpoint[/code]. The owners have their functions called in
## sequence of their path from the [code]endpoint[/code].
## The return value of the function in one node should be an array of arguments needed
## to relay to the call of the next.[br]
## The propagation ends once a node is found to have greater proximity to other endpoints.[br]
## Returns the last arrays of argument values when there are no more nodes to propagate to.
func propagate(endpoint:DijkstraNode, method:StringName, ...args) -> Array:
	#TODO Implement multi-threading.
	var owner = endpoint.get_meta("dijkstra_node_owner")
	if owner == null: return []
	if not owner.has_method(method): return []
	
	var conns : Array[DijkstraNode] = [endpoint]
	var costs : PackedInt32Array = [0]
	var state : Array[Array] = [owner.callv(method, args)]
	while not conns.is_empty():
		var new_conns : Array[DijkstraNode]
		var new_state : Array[Array]
		var i : int = -1
		for node : DijkstraNode in conns:
			i += 1
			if node.cost > costs[i]: continue
			# Only propagate in the local minimum region of costs, meaning
			# the affected nodes share the same endpoint as their closest.
			owner = node.get_meta("dijkstra_node_owner")
			if owner == null: continue
			if not owner.has_method(method): continue
			new_conns.append(node.connected)
			new_state.append(owner.callv(method, state[i]))
		conns = new_conns
		state = new_state
	return state

## Produce separate lists for separate graphs with given mapping queries.
## Each list only contains endpoints.[br]
## Optionally returns lists of node owners. This excludes objects of nodes without owner.[br]
## A network can be composed of multiple graphs, each graph being a group of
## nodes that can find each other through connections.
func find_graphs(queries:Array[DijkstraQuery], get_owners:=false) -> Array[Array]:
	var graphs : Array[Array]
	var accounted : Array[DijkstraNode]
	for query : DijkstraQuery in queries:
		for node in query.endpoints:
			if node in accounted:
				break
			graphs.append(query.endpoints)
			accounted.append_array(query.endpoints)
	if get_owners:
		var g : int = -1
		for graph in graphs.duplicate():
			g += 1
			var n : int = -1
			for node : DijkstraNode in graph:
				n += 1
				var owner = node.get_meta("djikstra_node_owner")
				if owner != null: graphs[g][n] = owner
	return graphs
