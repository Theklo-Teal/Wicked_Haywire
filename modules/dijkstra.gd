extends RefCounted
class_name Dijkstra

## A basic pathfinding class that finds the path in a network. It does this by associating
## a [code]cost[/code] value of travel to each [code]DijkstraNode[/code]. By default
## the travel cost is the smallest number of connections towards the closest target
## or endpoint. Many targets are allowed.[br]
## The cost can be influenced by setting a [code]weight[/code] to each nodes,
## which then changes the interpretation of the cost value.
## Most features will work with static functions, but if you require memory of past
## searches and to track which nodes are accounted in a network, you should instantiate
## this class. You may add nodes to [code]network[/code] and those of which are
## endpoints to [code]targets[/code], but calling [code]baking()[/code] will also
## register nodes if not found in those places.[br]
## Call [code]unregister()[/code] if you intend on removing nodes.

#TODO Maybe allow blocked nodes to have negative cost so they act like repulsors?

var timestamp : int = 0  ## [code]Time.get_ticks_usec()[/code] at the moment of map updating. Allows telling when was the last time [code]network[/code] costs were updated.
@export_storage var network : Dictionary[DijkstraNode, Dictionary]  ## Nodes registered to an instance of this class and associated to [code]weight[/code], [code]cost[/code] and [code]graph_id[/code] values independent of variables in [code]DijkstraNode[/code].
@export_storage var targets : Array[DijkstraNode]  ## The nodes known to be targets since the last call of [code]baking()[/code].


class Crawler:
	## An iterator that walks through the connections in breadth-first search, from 
	## each node in [code]origins[/code] until there are no more nodes left unvisited.
	## Each iteration returns an Array of arrays:
	## Index 0: All novel finds at a certain iteration.
	## Index 1: The nodes that connected to each find. The first set, corresponding to the index of [code]origins[/code] in the queue, will be [code]null[/code].
	## Index 2: The nodes that originated the propagation that lead to each find.
	## [code]DijkstraNode.refuse_connection() is honored, not counting links that were refused.[br]
	## You may provide a list of nodes to not test connections. The nodes in
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
			for conn in node.get_connections():
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
	
	var timestamp : int = 0  ## [code]Time.get_ticks_usec()[/code] at the moment of map updating. Allows telling if nodes were updated at different times, possibly because they are on separate graphs.
	@export_storage var graph_id : int = -1  ## Negative means value is invalid. Unique identifier given to a collection of nodes whenever [code]find_graphs()[/code] is called, distinguishing which nodes are connected in the same graph.
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
	func get_connections() -> Array[DijkstraNode]:
		return connected
	
	## If a node owner contains the method [code]dijkstra_mapped()[/code], that
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


## Something to do after a mapping operation is finished and once 
## [code]find_network_graphs()[/code] is called. It takes the Dictionary 
## returned by [code]baking()[/code] or [code]mapping()[/code].[br]
## By default it calls similar methods in the nodes of [code]queries[/code].[br]
## NOTE: [code]find_graphs()[/code] calls [code]DijkstraNode.graphs_mapped()[/code]
## directly without calling this function, if at all.
func graphs_mapped(queries:Dictionary[DijkstraNode, Array]):
	for endpoint in queries:
		var all = queries[endpoint] + [endpoint]
		for node in all:
			node.graphs_mapped()


## Gets the internal data of each [code]DijkstraNode[/code] in [code]network[/code] and
## updates the network with it.
func to_network():
	for node in network:
		network[node].weight = node.weight
		network[node].cost = node.cost
		network[node].graph_id = node.weight


## Gets the data stored in [code]network[/code] and updates the internal state
## of each corresponding node with it.
func from_network():
	for node in network:
		node.weight = network[node].weight
		node.cost = network[node].cost
		node.graph_id = network[node].graph_id

## Forget the given nodes from memory and clears their connections. This doesn't
## delete nodes, that has to be done by dereferrencing them from any variable.[br]
## This updates the network mapping, similarly to [code]connect_nodes()[/code].
## [code]internal[/code] can be set to [code]true[/code], if to also update the state within
## [code]DijkstraNode[/code] when mapping.
func unregister(internal:=false, ...nodes):
	var sieved = sieve_nodes(nodes)
	var all = sieved[0] + sieved[1]
	for each in all:
		network.erase(each)
		targets.erase(each)
		each.connected.clear()
	var queries = baking(internal)
	find_network_graphs(queries, internal)


## Connect two nodes of each pair together and updates [code]network[/code].[br]
## NOTE: It's safe to directly change a [code]DijkstraNode.connected[/code] property,
## then call [code]baking()[/code] or [code]mapping()[/code], and it would provide
## better ability to control the process, but this function simplifies basic cases.[br]
## You may use this function as a reference example on changing connections with
## sanitation and proper network management.
func connect_nodes(pairs:Array[Array], bidirectional:=false, internal:=false):
	var affected : Array[DijkstraNode]
	for pair in pairs:
		var start = pair[0]
		var stop = pair[1]
		if start == null or stop == null: continue
		if not (start is DijkstraNode and stop is DijkstraNode): continue
		
		if not stop in start.connected:
			affected.append(start)
			affected.append(stop)
			start.connected.append(stop)
			if bidirectional and start not in stop.connected:
				stop.connected.append(stop)
	var queries = baking.callv([internal] + seek_endpoints(affected))
	find_network_graphs(queries, internal)

## Disconnect two nodes of each pair and updates [code]network[/code]. If
## [code]bidirectional[/code] is true, it will also disconnect one-way connections
## in reverse direction.[br]
## NOTE: It's safe to directly change a [code]DijkstraNode.connected[/code] property,
## then call [code]baking()[/code] or [code]mapping()[/code], and it would provide
## better ability to control the process, but this function simplifies basic cases.[br]
## You may use this function as a reference example on changing connections with
## sanitation and proper network management.
func disconnect_nodes(pairs:Array[Array], bidirectional:=false, internal:=false):
	var affected : Array[DijkstraNode]
	for pair in pairs:
		var start = pair[0]
		var stop = pair[1]
		if start == null or stop == null: continue
		if not (start is DijkstraNode and stop is DijkstraNode): continue
		
		affected.append(start)
		affected.append(stop)
		start.connected.erase(stop)
		if bidirectional:
			stop.connected.erase(start)
	var queries = baking.callv([internal] + seek_endpoints(affected))
	find_network_graphs(queries, internal)


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
	timestamp = Time.get_ticks_usec()
	var accounting : Dictionary[DijkstraNode, Array]
	
	var sieved = sieve_nodes.callv(these)
	for node in sieved[0]:  # These are endpoints.
		if internal: node.timestamp = timestamp
		if not node in targets:
			targets.append(node)
	for node in sieved[1]:
		# These are valid, but not endpoints. They might have been included in 
		# the arguments, because their status changed and needs updating.
		if internal: node.timestamp = timestamp
		targets.erase(node)
		network.get_or_add(node, {"weight":node.weight, "cost":-1, "graph_id":-1})
	for node in targets:
		network.get_or_add(node, {"weight":node.weight, "cost":0, "graph_id":-1})
		accounting[node] = []
	
	for finds in Crawler.new(targets):
		print(finds[0])
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


## Updates [code]graph_id[/code] in [code]network[/code] to distinguish each node's
## graph. It uses the dictionary returned by [code]baking()[/code] and will call
## [code]graphs_mapped()[/code] after it's done.[br]
## Graphs are interconnected nodes in a network, disconnected from nodes of another graph.[br]
## It returns an array of node lists, each list representing a graph, with all
## owners of the nodes included in the graph. If there's no owner the node itself
## is added.[br]
## Optionally also update the node's [code]internal[/code] value.
func find_network_graphs(queries:Dictionary[DijkstraNode, Array], internal:=false) -> Array[Array]:
	var graphs :  Array[Array]
	var accounted : Array[DijkstraNode]
	for endpoint in queries:
		var all = queries[endpoint] + [endpoint]
		for node in all:
			if not node in accounted:
				accounted.append_array(accounted)
				graphs.append(all)
				break
	var owners : Array[Array]
	for id in range(graphs.size()):
		owners.append([])
		for node in graphs[id]:
			owners[id].append(node if node.owner == null else node.owner)
			network[node].graph_id = id
			if internal: node.graph_id = id
	graphs_mapped(queries)
	return owners


## Run a search through all nodes in [code]these[/code]. If they aren't endpoints,
## meaning that [code]DijkstraNode.is_target[/code] is [code]false[/code], then
## It first searches an endpoint leading to them, which will slowdown the opeartion.[br]
## Novel endpoints discovered along the way initiate further searches, but from
## the time of discovery, rather than at beginning of the call.[br]
## Use [code]find_graphs()[/code] to update [code]DijkstraNode.graph_id[/code].[br]
## This returns a Dictionary where the key is an endpoint and the value is a list
## of nodes found by searching from them.
static func mapping(...these) -> Dictionary[DijkstraNode, Array]:
	@warning_ignore("shadowed_variable")
	var timestamp : int = Time.get_ticks_usec()
	var accounting : Dictionary[DijkstraNode, Array]
	
	var endpoints = seek_endpoints.callv(these)
	for finds in Crawler.new(endpoints):
		var i : int = -1
		for node in finds[0]:
			node.timestamp = timestamp
			node.cost = -1
			node.graph_id = -1
			if node.is_target:
				node.cost = 0
				if not node in endpoints:
					#TODO search from the novel targets anew.
					endpoints.append(node)
			else:
				if node.cost < 0:
					node.cost = node.weight
				if finds[1][i] != null:
					node.cost = min(finds[1][i].cost + node.weight, node.cost)
				accounting[finds[2][i]].append(node) 
	return accounting


## Updates [code]graph_id[/code] in [code]DijsktraNode[/code] to distinguish each node's
## graph. It uses the dictionary returned by [code]mapping()[/code] and if
## [code]notify_mapped[/code] is [code]true[/code], will call
## [code]DijkstraNode.graphs_mapped()[/code] on each node.[br]
## Graphs are interconnected nodes in a network, disconnected from nodes of another graph.[br]
## It returns an array of node lists, each list representing a graph, with all
## owners of the nodes included in the graph. If there's no owner the node itself
## is added.[br]
static func find_graphs(queries:Dictionary[DijkstraNode, Array], notify_mapped:=true) -> Array[Array]:
	var graphs :  Array[Array]
	var accounted : Array[DijkstraNode]
	for endpoint in queries:
		var all = queries[endpoint] + [endpoint]
		for node in all:
			if not node in accounted:
				accounted.append_array(accounted)
				graphs.append(all)
				break
	var owners : Array[Array]
	for id in range(graphs.size()):
		owners.append([])
		for node in graphs[id]:
			owners[id].append(node if node.owner == null else node.owner)
			node.graph_id = id
			if notify_mapped:
				node.graphs_mapped()
	return owners


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


## Given a selection of nodes, finds the endpoints of the same graph as them.
## If endpoints are provided, they are including in the returned list, but don't
## initiate a search.[br]
## NOTE: This uses the [code]Crawler[/code] iterator and doesn't rely on mapping.[br]
## This makes it robust against outdated or indeterminate graphs.[br]
## Use [code]search()[/code] to find the endpoint leading to a node using the
## pre-computed costs in mapping, which is faster operation.
static func seek_endpoints(...these) -> Array[DijkstraNode]:
	var sieved = sieve_nodes.callv(these)
	var endpoints : Array[DijkstraNode] = sieved[0]
	for finds : Array in Crawler.new(sieved[1], sieved[0]):
		for node in finds[0]:
			if node.is_target:
				endpoints.append(node)
				break
	return endpoints


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
		var naibaro = curr.get_connections()
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
	var search1 = search(bridge1)
	search1.reverse()  # Make the path from the endpoint to the bridge
	return search1 + search(bridge2)  # endpoint1 -> bridge1 -> bridge2 -> endpoint2

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

## Returns a list of owners of the given nodes. Ignores those without a owner
## or not [code]DijkstraNode[/code]
static func get_owners(...nodes) -> Array:
	var owners : Array
	var sieved = sieve_nodes.callv(nodes)
	for node in sieved[0] + sieved[1]:
		if node.owner != null:
			owners.append(node.owner)
	return owners

## Returns a list of [code]property[/code] values in owners of the given nodes.
## Ignores those without a owner or not [code]DijkstraNode[/code].[br]
## If the given property doesn't exist, uses [code]default[/code].
static func get_owners_property(nodes:Array[DijkstraNode], property:StringName, default=null) -> Array:
	var owners : Array
	var sieved = sieve_nodes.callv(nodes)
	for node : DijkstraNode in sieved[0] + sieved[1]:
		if node.owner != null:
			if property in node.owner:
				owners.append(node.owner.get(property))
			else:
				owners.append(default)
	return owners

## Returns a list of [code]method[/code] return values in owners of the given nodes.
## Ignores those without a owner or not [code]DijkstraNode[/code][br]
## If the given method doesn't exist, uses [code]default[/code].
static func get_owners_method(nodes:Array[DijkstraNode], method:StringName, default=null, ...args) -> Array:
	var owners : Array
	var sieved = sieve_nodes.callv(nodes)
	for node : DijkstraNode in sieved[0] + sieved[1]:
		if node.owner != null:
			if node.owner.has_method(method):
				owners.append(node.owner.callv(method, args))
			else:
				owners.append(default)
	return owners


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
## path from the [code]origin[/code], to their common endpoint, then from there to
## all other nodes in the region.[br]
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
