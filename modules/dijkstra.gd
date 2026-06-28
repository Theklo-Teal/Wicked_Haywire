extends RefCounted
class_name Dijkstra

## A basic pathfinding class that finds the path in a network. It does this by setting a
## [code]cost[/code] value of travel on each [code]DijkstraNode[/code]. By default
## the travel cost is the smallest number of connections towards the closest target
## or endpoint. Many targets are allowed.[br]
## The cost can be influenced by setting a [code]weight[/code] to each nodes,
## which then changes the interpretation of the cost value.

#TODO Handle deleted DijkstraNode.
#TODO Maybe allow blocked nodes to have negative cost so they act like repulsors?
#TODO Handle mapping if there have never been known targets.
#FIXME The mapping functions when targets change...


var network : Dictionary[DijkstraNode, Dictionary]  ## Nodes registered to an instance of this class and associated to [code]weight[/code], [code]cost[/code] and [code]graph_id[/code] values independent of variables in [code]DijkstraNode[/code].
var targets : Array[DijkstraNode]  ## The nodes known to be targets since the last call of [code]baking()[/code].


class Crawler:
	## An iterator that walks through the connections in breadth-first search, from 
	## each node in [code]origins[/code] until there are no more nodes left unvisited.
	## Each iteration returns an Array of arrays:
	## Index 0: All novel finds at a certain iteration.
	## Index 1: The nodes that connected to each find. The first set, corresponding to the index of [code]origins[/code] in the queue, will be [code]null[/code].
	## Index 2: The nodes that originated the propagation that lead to each find.
	## [code]DijkstraNode.refuse_connection(), not counting links that were refused.[br]
	## You may provide a list of nodes to not test connections. These nodes to
	## [code]ignore[/code] will appear at the beginning of [code]queue[/code], but
	## never returned.
	var _origins : Array[DijkstraNode]  ## The first node to be visited that lead to corresponding queue entry.
	var sources : Array[DijkstraNode]  ## Nodes from which those in [code]queue[/code] were found.
	var queue : Array[DijkstraNode]  ## Nodes found.
	var _ini_head : int = 0
	func _init(origins:Array[DijkstraNode], ignore:Array[DijkstraNode]=[]) -> void:
		_origins = ignore + origins
		queue = ignore + origins
		sources.resize(queue.size())
		sources.fill(null)
		_ini_head = ignore.size()
	func may_proceed(head:int):
		return head < queue.size()
	
	func _iter_init(iter: Array) -> bool:
		iter[0] = _ini_head
		return may_proceed(iter[0])
	func _iter_next(iter: Array) -> bool:
		var head = iter[0]
		iter[0] += queue.size()
		var i : int = -1
		for node : DijkstraNode in queue.slice(head, queue.size()):
			i += 1
			for conn in node.connected:
				if not conn in queue and not conn.refuse_connection(node):
					sources.append(node)
					queue.append(conn)
					#TODO Test this.
					if node == null:
						_origins.append(node)
					else:
						_origins.append(_origins[i])
		return may_proceed(iter[0])
	func _iter_get(iter: Variant) -> Array[Array]:
		var zip : Array[Array] = [[], [], []]
		for i in range(iter, queue.size()):
			zip[0].append(queue[i])
			zip[1].append(sources[i])
			zip[2].append(_origins[i])
		return zip


class DijkstraNode extends Resource:
	## Encapsulated data for node in a graph. This could be better implement if there
	## was "traits" programming feature.[br]
	## Each object representing a node in a network, should hold an instance of this
	## class. Any pathfinding operation will either read or modify this instance.[br]
	## This class can be extended to affect things like [code]weight[/code] or
	## how connections are found.
	
	var timestamp : int = 0  ## [code]Time.get_ticks_usec()[/code] at the moment of map updating. Allows telling if node is outdated.
	var graph_id : int = -1  ## Negative means value is invalid. Unique identifier given to a collection of nodes whenever [code]find_graphs()[/code] is called, distinguishing which nodes are connected in the same graph.
	@export_storage var owner : Object
	@export var exclude := false  ## Whether to refuse connections to this node. [code]Dijkstra.mapping()[/code] must be called for changes to take effect. Prefer using [code]set_enabled()[/code]. The effect of this variable depends on the implementation of [code]refuse_connection()[/code].
	@export var cost : int = 0  ## Cost of travelling from this node to the closest endpoint.
	@export var weight : int = 1 ## Cost of connecting to this node
	@export var is_target := false  ## Whether this is an endpoint of the graph.
	@export_storage var connected : Array[DijkstraNode]  ## List of nodes, representing a one-way connection with them.
	
	## Include the object [code]associate[/code] to this graph node, which
	## represents something in a graph. It is stored as [code]owner[/code].
	func _init(associate:Object=null) -> void:
		owner = associate
		cost = -1
	
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
	
	## Whether to refuse connecting from [code]source_node[/code].[br]
	## By default relays [code]exclude[/code], effectively refusing all connections
	## if set to [code]true[/code].
	@warning_ignore("unused_parameter")
	func refuse_connection(source_node:DijkstraNode=null) -> bool:
		return exclude
		#if source_node == null or source_node.owner.coord.x < owner.coord.x:
			#return exclude
		#else:
			#return false
	
	## The cost of the connection from [code]source_node[/code] to this one.
	@warning_ignore("unused_parameter")
	func get_weight(source_node:DijkstraNode=null) -> int:
		return weight
	
	## By default returns [code]connected[/code], but can be overriden for more
	## complex behavior.
	@warning_ignore("unused_parameter")
	func get_connections(source_node:DijkstraNode=null) -> Array[DijkstraNode]:
		return connected
	
	## If a node owner contains the method [code]dijkstra_mapped[/code], that
	## will be called when a mapping operation is finished and the node of
	## that owner was involved.
	func _graphs_mapped():
		if owner != null and owner.has_method("dijkstra_mapped"):
			owner.dijkstra_mapped()
		graphs_mapped()
	## What to do when this node was found while mapping a network
	## and the mapping is finished?
	func graphs_mapped():
		pass


#TODO refactor this.
## Something to do when a mapping operation is finished.[br]
## By default it calls similar methods in the given [code]queries[/code].
func graphs_mapped(queries:Dictionary):
	for each in queries:
		each.graphs_mapped()


## Set whether the given nodes are to be excluded from navigation and updates it
## with [code]baking()[/code]. Returns its result.[br]
func node_exclusion(exclude:bool, ...these) -> Dictionary[DijkstraNode, Array]:
	var sieved = sieve_nodes(these)
	for node in sieved[0] + sieved[1]:
		node.exclude = exclude
	return baking(sieved[0])


## Changes the weights of given nodes in [code]network[/code]. Optionally also
## also updates their [code]internal[/code] value [code]Dijkstra.weight[/code].[br]
## Nodes not found in [code]network[/code] are added.[br]
## Optionally update the network costs at the end.
func set_weights(these:Dictionary, internal:=false, update:=false):
	for node in these:
		var info = network.get_or_add(node, {"weight":1, "cost":-1, "graph_id":-1})
		info.weight = these[node]
		if internal: these.weight = these[node]
	if update: baking.callv([internal] + these.keys())


## Given a selection of nodes, finds the endpoints of the same graph as them.
## If endpoints are provided, they are including in the returned list, but don't
## initiate a search.
static func seek_endpoints(...these) -> Array[DijkstraNode]:
	var sieved = sieve_nodes(these)
	var endpoints : Array[DijkstraNode] = sieved[0]
	for finds : Array in Crawler.new(sieved[1], sieved[0]):
		for node in finds[0]:
			if node.is_target:
				endpoints.append(node)
	return endpoints



## Run a search through all nodes in [code]targets[/code]. If new endpoints are
## found or some aren't targets anymore, [code]targets[/code] is updated accordingly.
## Other nodes are added to [code]network[/code] if not already there and given a
## Dictionary with [code]cost[/code] updated, and [code]graph_id[/code] resetted.
## Use [code]find_network_graphs()[/code] to update the [code]graph_id[/code].[br]
## You may choose to also update each node's [code]internal[/code] values, getting
## the same behavior as with [code]mapping()[/code].[br]
## If nodes are given as arguments, it sets or unsets them as [code]targets[/code],
## initiating search from them, which might improve performance.[br]
## Novel endpoints discovered along the way initiate further searches, but from
## the time of discovery, rather than at beginning of the call.[br]
## This returns a Dictionary where the key is an endpoint and the value is a list
## of nodes found by searching from them.
func baking(internal:bool=true, ...these) -> Dictionary[DijkstraNode, Array]:
	var timestamp : int = Time.get_ticks_usec()
	var accounting : Dictionary[DijkstraNode, Array]
	
	var sieved = sieve_nodes(these)
	for each in sieved[0]:  # These are endpoints.
		if not each in targets:
			targets.append(each)
	for each in sieved[1]:  # These are valid, but not endpoints.
		targets.erase(each)
	for node in targets:
		if internal: node.timestamp = timestamp
		network.get_or_add(node, {"weight":node.weight, "cost":0, "graph_id":-1})
		accounting[node] = []
	
	for finds in Crawler.new(targets):
		var i : int = -1
		for node in finds[0]:
			i += 1
			var info = network.get_or_add(node, {"weight":node.weight, "cost":-1, "graph_id":-1})
			if internal:
				node.timestamp = timestamp
				node.cost = -1
				node.graph_id = -1
				info.cost = -1
				info.graph_id = -1
			if node.is_target:
				if internal: node.cost = 0
				info.cost = 0
				if not node in targets:
					#TODO search from the novel targets anew.
					targets.append(node)
			else:
				if info.cost < 0: info.cost = info.weight
				if finds[1][i] != null:
					info.cost = min(finds[1][i].cost + info.weight, info.cost)
				if internal: node.cost = info.cost
				accounting[finds[2][i]].append(node) 
	
	return accounting


#func find_network_graphs():
#	pass


#static func mapping(internal:bool=true, ...these) -> Dictionary[DijkstraNode, Array]:
#	var timestamp : int = Time.get_ticks_usec()


## Produces separate lists for separate graphs with the Dictionary returned from
## [code]mapping()[/code]. Each list only contains endpoints. The nodes will have
## [code]DijkstraNode.graph_id[/code] set to a sequential number according to the
## graph they belong.[br]
## A network can be composed of multiple graphs, each graph being a group of
## nodes that can find each other through connections.
#static func find_graphs(queries:Array[DijkstraQuery], get_owners:=false) -> Array[Array]:
	#var graphs : Array[Array]
	#var accounted : Array[DijkstraNode]
	#for query : DijkstraQuery in queries:
		#var endpoints = query.endpoints + [query.queue[0]]
		#for node in endpoints:
			#if node in accounted:
				#break
			#graphs.append(endpoints)
			#accounted.append_array(endpoints)
	#var _graphs : Array[Array]
	#var id : int = 0
	#for graph in graphs:
		#var content : Array
		#for node : DijkstraNode in graph:
			#node.graph_id = id
			#if get_owners:
				#if node.owner != null: content.append(node.owner)
			#else:
				#content.append(node)
		#if not content.is_empty():
			#id += 1
			#_graphs.append(content)
		#return _graphs
	#return graphs


## Sanitation for the inputs of [code]mapping()[/code] or [code]baking()[/code].
## It returns an array containing endpoints at index 0 and one containing
## valid non-endpoint nodes at index 1.
static func sieve_nodes(...these) -> Array[Array]:
	var endpoints : Array[DijkstraNode]
	var other : Array[DijkstraNode]
	for node in these:
		if node == null:
			continue
		if not node is DijkstraNode:
			continue
		if node.is_target:
			endpoints.append(node)
		else:
			other.append(node)
	return [endpoints, other]


## After computing travel costs of nodes with [code]mapping()[/code],
## this returns the owners of nodes from [code]origin[/code] along the way with 
## the least cost until a target is found. 
## If nodes have no owner, we return the node itself.[br]
## The order of returned objects follows the path found to the target.
## If can't be found returns partial path, if told to.[br]
## Nodes that refuse connection will be avoided. The [code]origin[/code] node 
## is not affected by this.[br]
static func search(origin:DijkstraNode, partial:=false) -> Array:
	var curr : DijkstraNode = origin
	var path : Array[DijkstraNode] = [origin]
	var options : Array[DijkstraNode]
	while not path.back().is_target:
		var naibaro = curr.get_connections(origin)
		for node in naibaro:
			if node.refuse_connection(curr):
				continue
			if node.cost < 0:
				continue
			if node in options:
				continue
		if naibaro.size() == 0:
			curr = options.pop_back()
			if curr == null:
				# Nowhere to go, return with partial solution.
				break
			# Backtrack and attempt an alternate path.
			continue
		naibaro.sort_custom(func(a, b): return a.cost > b.cost)
		options.append_array(naibaro)
		curr = options.pop_back()
		path.append(curr)
		
	
	if not (path.back().is_target or partial):
		# The last node is not a target and we don't want partial paths.
		return []
	
	var path_owners : Array
	for node in path:
		path_owners.append( node if node.owner == null else node.owner )
	return path_owners


## Finds the shortest path between the two target nodes. If there are one-way
## connections, it will only return a path coming from [code]start[/code] and
## entering the region of [code]stop[/code].
static func search_between(start:DijkstraNode, stop:DijkstraNode):
	var region1 = region_of(start)
	var region2 = region_of(stop)
	var bridge1 : DijkstraNode
	var bridge2 : DijkstraNode
	var best_cost : int = -1
	for node1 in region1:
		for node2 in region2:
			if node2 in node1.connected:
				var this_cost = node1.cost + node2.cost
				if best_cost == -1 or this_cost < best_cost:
					bridge1 = node1
					bridge2 = node2
					best_cost = this_cost
	return search(bridge1) + search(bridge2)

## Find if the two nodes are in the same region.
## Nodes of the same regions have a common target node as the closest to them.[br]
static func same_region(node1:DijkstraNode, node2:DijkstraNode) -> bool:
	var path1 = search(node1)
	var path2 = search(node2)
	if path1 == null or path2 == null: return false
	return path1.back() == path2.back()

## This walks throughout the connections of target node [code]endpoint[/code] until
## it finds nodes with more proximity to another target node. It returns the nodes
## at the edges of the jurisdiction of [code]endpoint[/code].[br]
static func region_of(endpoint:DijkstraNode) -> Array[DijkstraNode]:
	#TODO Implement multi-threading.
	var conns : Array[DijkstraNode] = endpoint.connected
	var costs : Array[int] = [endpoint.cost]
	var edges : Array[DijkstraNode]
	while not conns.is_empty():
		edges = conns
		var new_conns : Array[DijkstraNode]
		var new_costs : Array[int]
		var i : int = -1
		for node in conns:
			i += 1
			for conn in node.connected:
				if node.cost > costs[i] and node not in new_conns:
					new_conns.append(node)
					new_costs.append(node.cost)
		conns = new_conns
		costs = new_costs
	return edges

## Cause propagation of a function call to all owners of nodes with cost above
## [code]origin.cost[/code] and in the same graph region as [code]origin[/code].[br]
## Nodes of the same regions have a common target node as the closest to them.[br]
## The owners of found nodes have their functions called in sequence of their
## path from the [code]origin[/code].[br]
## The return value of the method in one node should be an array of arguments needed
## to relay to the call of the next.[br]
## The propagation ends once a node is found to have greater proximity to other
## endpoints, therefore exiting the same region.[br]
## Returns the last arrays of argument values when there are no more nodes to propagate to.
static func propagate_fore(origin:DijkstraNode, method:StringName, ...args) -> Array:
	#TODO Implement multi-threading.
	if origin.owner == null: return []
	if not origin.owner.has_method(method): return []
	
	var prev : Array[DijkstraNode] = [origin]
	prev.append_array(origin.connected)
	var conns : Array[DijkstraNode] = origin.connected
	var costs : PackedInt32Array = [origin.cost]
	var state : Array[Array] = [origin.owner.callv(method, args)]
	while not conns.is_empty():
		var new_conns : Array[DijkstraNode] = []
		var new_state : Array[Array] = []
		var i : int = -1
		for node : DijkstraNode in conns:
			i += 1
			if node.cost > costs[i]: continue
			# Only propagate towards rising cost. At the edge of a region costs
			# will start decreasing, so this also catches when exiting a region.
			if node.owner == null: continue
			if not node.owner.has_method(method): continue
			for conn in node.connected:
				if not conn in prev:
					prev.append(conn)
					new_conns.append(conn)
			new_state.append(node.owner.callv(method, state[i]))
		conns = new_conns
		state = new_state
	return state

## Cause propagation of a function call to all owners of nodes with cost below
## [code]origin.cost[/code] and in the same graph as [code]origin[/code].[br]
## Nodes of the same regions have a common target node as the closest to them.[br]
## The owners of found nodes have their functions called in sequence of their
## path from the [code]origin[/code].[br]
## The return value of the method in one node should be an array of arguments needed
## to relay to the call of the next.[br]
## The propagation ends once all paths found lead to the same target node.[br]
## Returns the last arrays of argument values when there are no more nodes to propagate to.
static func propagate_back(origin:DijkstraNode, method:StringName, ...args) -> Array:
	#TODO Implement multi-threading.
	if origin.owner == null: return []
	if not origin.owner.has_method(method): return []
	
	var prev : Array[DijkstraNode] = [origin]
	prev.append_array(origin.connected)
	var conns : Array[DijkstraNode] = origin.connected
	var costs : PackedInt32Array = [origin.cost]
	var state : Array[Array] = [origin.owner.callv(method, args)]
	while not conns.is_empty():
		var new_conns : Array[DijkstraNode] = []
		var new_state : Array[Array] = []
		var i : int = -1
		for node : DijkstraNode in conns:
			i += 1
			if node.cost < costs[i] and node.cost > 0 : continue
			# Only propagate towards lowering cost. We stop propagating at cost
			# zero, because that means we've hit an endpoint.
			if node.owner == null: continue
			if not node.owner.has_method(method): continue
			for conn in node.connected:
				if not conn in prev:
					prev.append(conn)
					new_conns.append(conn)
			new_state.append(node.owner.callv(method, state[i]))
		conns = new_conns
		state = new_state
	return state

## Cause propagation of a function call to all owners of nodes in the same graph
## and region as [code]origin[/code].[br]
## Nodes of the same regions have a common target node as the closest to them.[br]
## The owners of found nodes have their functions called in sequence of their
## path from the [code]origin[/code].[br]
## The return value of the method in one node should be an array of arguments needed
## to relay to the call of the next.[br]
## The propagation ends for nodes that are at the edges of a region.[br]
## Returns the last arrays of argument values when there are no more nodes to propagate to.
#func propagate_region(origin:DijkstraNode, method:StringName, ...args) -> Array:
#	return []

## Cause propagation of a function call to all owners of nodes in the same graph
## as [code]origin[/code] regardless of region[br]
## The owners of found nodes have their functions called in sequence of their
## path from the [code]origin[/code].[br]
## The return value of the method in one node should be an array of arguments needed
## to relay to the call of the next.[br]
## The propagation ends once all nodes in the same graph have been visited.[br]
## Returns the last arrays of argument values when there are no more nodes to propagate to.
#func propagate_graph(origin:DijkstraNode, method:StringName, ...args) -> Array:
#	return []
