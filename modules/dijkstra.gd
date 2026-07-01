extends RefCounted
class_name Dijkstra

## A basic pathfinding class that finds the path in a network. It does this by associating
## a [code]cost[/code] value of travel to each [code]DijkstraNode[/code]. By default
## the travel cost is the smallest number of connections towards the closest target
## or endpoint. Many targets are allowed.[br]
## The cost can be influenced by setting a [code]weight[/code] to each nodes,
## which then changes the interpretation of the cost value.[br]
## Most features will work with static functions, but if you require memory of past
## searches and to track which nodes are accounted in a network, you should instantiate
## this class. You may add nodes to [code]network[/code] and those of which are
## endpoints to [code]targets[/code], but calling [code]baking()[/code] will also
## register nodes if not found in those places.[br]
## Call [code]unregister()[/code] if you intend on removing nodes.
## The class includes a [code]Crawler[/code] which is an iterator that will discover
## connections from given starting nodes.

#TODO Maybe the `refuse_connection()` check shouldn't be handled by the Crawler?
#TODO Maybe allow blocked nodes to have negative cost so they act like repulsors?
#TODO Non-static `travel()` which takes costs from `network`
#TODO Allow back-tracking in `travel()` and `inverse_travel()`

var timestamp : int = 0  ## [code]Time.get_ticks_usec()[/code] at the moment of map updating. Allows telling when was the last time [code]network[/code] costs were updated.
@export_storage var network : Dictionary[DijkstraNode, Dictionary]  ## Nodes registered to an instance of this class and associated to [code]timestamp[/code], [code]weight[/code], [code]cost[/code] and [code]graph_id[/code] values independent of variables in [code]DijkstraNode[/code].
@export_storage var targets : Array[DijkstraNode]  ## The nodes known to be targets since the last call of [code]baking()[/code].

enum SEEK {  ## Crawler mode
	NODES,  ## Return list of where found nodes appear only once.
	LINKS  ## Return list of nodes for every connection they have.
}

class Crawler:
	## From a given endpoint [code]DijkstraNode[/code], finds all nodes in the same
	## graph and only once. Each time [code]iterate()[/code] is called, the search
	## Advances, returning the iteration's new finds, so they can be analysed.[br]
	## If something of interest is found, it doesn't need to search any further.[br]
	## If it can't find any new nodes, iteration will return empty arrays.[br]
	## You can get all found nodes in the [code]nodes[/code] property and all
	## unique connections in [code]links[/code]. This class will seek nodes and
	## connections at the same time, so it might not yet have all links filled in
	## after all nodes have been found.[br]
	## You may run all iterations in a single call with [code]all_iterate()[/code].

	
	var _origin : DijkstraNode
	var ignore : Array[DijkstraNode]  ## A list of nodes to avoid visiting.
	var excluded : Array[DijkstraNode]  ## Node with [code]DijkstraNode.exclude[/code] set [code]true[/code].
	var _head : int = 0
	var _queue : Array[DijkstraNode]  # Visited nodes. Entries ahead of `_head` are yet to be visited.
	
	var _nodes_head : int = 0
	var _prevs : Array[DijkstraNode]
	var nodes : Array[DijkstraNode]  ## All nodes found.
	
	var _links_head : int = 0
	var links : Dictionary[Array, bool]  ## [code][link_start, link_stop] -> bool[/code]; All links found. The Dictionary is being used as a Set and the [code]bool[code] means nothing.
	
	## Given a node to search from, set up the Crawler.
	func _init(source:DijkstraNode, ...to_ignore):
		ignore.assign(to_ignore)
		if source.exclude: excluded.append(source)
		_origin = source
		reset()
	
	func is_finished():
		return not _head < _queue.size()
	
	func reset():
		_head = 0
		_queue = [_origin]
		_nodes_head = 0
		_links_head = 0
		_prevs.clear()
		nodes.clear()
		links.clear()
	
	## Go through all iterations in one go and return all finds. If no node is
	## given to ignore, it uses the current [code]ignore[/code] list. Otherwise
	## overwrites it.
	func all_iterate(seek:=SEEK.NODES, to_ignore:Array[DijkstraNode]=[]) -> Array[Array]:
		reset()
		if not to_ignore.is_empty():
			ignore.assign(to_ignore)
		var all_finds : Array[Array]
		var new_find_count : int = 1
		while _head < _queue.size() and new_find_count > 0:
			var finds = iterate(seek)
			new_find_count = finds.size()
			all_finds.append_array(finds)
		return all_finds
	
	## Get the novel nodes found since last call to [code]iterate()[/code].[br]
	## Returns an array of pairs with novel nodes at index 1 and their previous
	## node that connected to them at index 0.
	func get_iter_nodes() -> Array[Array]:
		var zip : Array[Array]= []
		for i in range(_nodes_head, nodes.size()):
			zip.append([_prevs[i], nodes[i]])
		return zip
	
	## Get the novel links found since last call to [code]iterate()[/code].
	## Returns an array of pairs of nodes, index 0 being where a connection
	## was found and index 1 where that connection lead to.
	func get_iter_links() -> Array[Array]:
		var slice : Array[Array] = []
		var _links = links.keys()
		for i in range(_links_head, links.size()):
			slice.append(_links[i])
		return slice
	
	## Step through discovery of nodes and links. Will return empty arrays if it
	## can't find any more of what you [code]seek[/code].
	func iterate(seek:=SEEK.NODES) -> Array[Array]:
		if _head >= _queue.size(): return []
		var next_head = _queue.size()
		for node : DijkstraNode in _queue.slice(_head, _queue.size()):
			if node in ignore: continue
			for conn in node.get_connections(_origin, node):
				if conn in ignore: continue
				if conn.exclude: excluded.append(conn)
				if conn.refuse_connection(_origin, node): continue
				if not conn in nodes:
					_prevs.append(node)
					nodes.append(conn)
				var pair = [node, conn]
				if not pair in links:
					links[pair] = false
					_queue.append(conn)
		_head = next_head
		var iter = [get_iter_nodes, get_iter_links][seek].call()
		_nodes_head = nodes.size()
		_links_head = links.size()
		return iter

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
	@export var cost : int = -1  ## Cost of travelling from this node to the closest endpoint.
	@export var weight : int = 1 ## Cost of connecting to this node
	@export var is_target := false  ## Whether this is an endpoint of the graph.
	@export_storage var connected : Array[DijkstraNode]  ## List of nodes, representing a one-way connection with them.
	
	## Include the object [code]associate[/code] to this graph node, which
	## represents something in a graph. It is stored as [code]owner[/code].
	func _init(associate:Object=null) -> void:
		owner = associate
		cost = -1
	
	func to_dict() -> Dictionary:
		return {
			"timestamp": timestamp,
			"weight": weight,
			"cost": 0 if is_target else cost,
			"graph_id": graph_id,
			}
	
	## Whether to refuse connecting from [code]source_node[/code].[br]
	## By default relays [code]exclude[/code], effectively refusing all connections
	## if set to [code]true[/code].
	@warning_ignore("unused_parameter")
	func refuse_connection(origin_node:DijkstraNode=null, source_node:DijkstraNode=null) -> bool:
		return exclude
	
	## The cost of the connection from [code]source_node[/code] to this one.
	@warning_ignore("unused_parameter")
	func get_weight(origin_node:DijkstraNode=null, source_node:DijkstraNode=null) -> int:
		return weight
	
	## By default returns [code]connected[/code], but can be overriden for more
	## complex behavior.
	@warning_ignore("unused_parameter")
	func get_connections(origin_node:DijkstraNode=null, source_node:DijkstraNode=null) -> Array[DijkstraNode]:
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
func graphs_mapped(queries:Dictionary[DijkstraNode, Crawler]):
	for endpoint in queries:
		var all = queries[endpoint].nodes + [endpoint]
		for node in all:
			node.graphs_mapped()


## Gets the internal data of each [code]DijkstraNode[/code] in [code]network[/code] and
## updates the network with it.[br]
## By default updates the whole [code]network[/code] otherwise you can specify
## a selection.[br]
## Usually, the weight of a link is calculated with [code]DijkstraNode.get_weight()[/code]
## but weights in the network are static and require an external way to update them
## if necessary.
func to_network(...nodes):
	if nodes.is_empty(): nodes = network.keys()
	for node in nodes:
		network[node].timestamp = node.timestamp
		network[node].weight = node.weight
		network[node].cost = node.cost
		network[node].graph_id = node.weight


## Gets the data stored in [code]network[/code] and updates the internal state
## of each corresponding node with it.[br]
## By default updates the whole [code]network[/code] otherwise you can specify
## a selection.[br]
## Usually, the weight of a link is calculated with [code]DijkstraNode.get_weight()[/code]
## but weights in the network are static. This sets [code]DijkstraNode.weight[/code]
## directly.
func from_network(...nodes):
	if nodes.is_empty(): nodes = network.keys()
	for node in nodes:
		node.timestamp = network[node].timestamp
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
## NOTE: The Crawler won't check [code]DijkstraNode.excluded[/code] directly,
## but call [code]DijkstraNode.refuse_connection()[/code] instead.
func node_exclusion(exclude:bool, ...these) -> Dictionary[DijkstraNode, Crawler]:
	var sieved = sieve_nodes(these)
	for node in sieved[0] + sieved[1]:
		node.exclude = exclude
	return baking.callv([null, true] + sieved[0])


## Run a search through all connections in [code]targets[/code]. If new endpoints are
## found or some aren't targets anymore, [code]targets[/code] is updated accordingly.
## Other nodes are added to [code]network[/code] if not already there and given a
## Dictionary with [code]cost[/code] updated, and [code]graph_id[/code] resetted.[br]
## If [code]internal[/code] is [code]true[/code], the weight is found through 
## [code]DijkstraNode.get_weight()[/code] otherwise the static value in the network.[br]
## You may choose to also update each node's [code]internal[/code] values, getting
## the same behavior as with [code]mapping()[/code].[br]
## Use [code]find_network_graphs()[/code] to update the [code]graph_id[/code].[br]
## If no nodes are given as argument, it uses [code]targets[/code] as a memory of
## known endpoints, otherwise it sets or unsets the given ones from [code]targets[/code]
## from the start, initiating search from them, which might improve performance.[br]
## Novel endpoints discovered along the way initiate further searches, but from
## the time of discovery, rather than at beginning of the call.[br]
## If no endpoints are provided or known, the function will aggressively insist
## on finding endpoints from given nodes and [code]network[/code] before starting
## proper search. This might take much longer to solve and if no endpoints are ever
## found, the network isn't updated.[br]
## This returns a Dictionary where the keys are endpoints and the values are their
## Crawler instance with information of connected nodes.
func baking(internal:bool, ...these) -> Dictionary[DijkstraNode, Crawler]:
	timestamp = Time.get_ticks_usec()
	var accounting : Dictionary[DijkstraNode, Crawler]
	
	# Sanitation and categorization
	var sieved = sieve_nodes.callv(these + targets)
	for node : DijkstraNode in sieved[0]:  # These are endpoints.
		if not node in targets:
			targets.append(node)
		network.get_or_add(node, node.to_dict())
	for node : DijkstraNode in sieved[1]:
		# These are valid, but not endpoints. They might have been included in 
		# the arguments, because their status changed and needs updating.
		targets.erase(node)
		network.get_or_add(node, node.to_dict())
	
	# No targets provided?
	if targets.is_empty():
		# Search endpoints in the network
		var netnodes = network.keys()
		for node : DijkstraNode in netnodes:
			if node.is_target:
				targets.append(node)
		if targets.is_empty():
			# Non of the network nodes is a target, so search for one
			# from them than might not have been registered.
			targets = seek_endpoints.callv(netnodes)
	if targets.is_empty() and not sieved[1].is_empty():
		# Try finding them connected to given nodes.
		#NOTE with do this after checking known network nodes because that's
		# faster.
		targets = seek_endpoints.callv(sieved[1])
	if targets.is_empty():
		# Still no targets? Nothing we can do.
		return {}
	
	for node : DijkstraNode in targets:
		var tgt = network.get_or_add(node, node.to_dict())
		tgt.timestamp = timestamp
		tgt.cost = 0
		tgt.graph_id = -1
		accounting[node] = Crawler.new(node)
	if internal: from_network.callv(targets)
	
	var halt := false
	while halt == false:
		halt = true
		for orig in accounting:
			var crawl = accounting[orig]
			var finds : Array[Array] = crawl.iterate(SEEK.LINKS)
			if not crawl.is_finished():halt = false
			for pair : Array[DijkstraNode] in finds:
				var start = network[pair[0]]
				var stop = network.get_or_add(pair[1], pair[1].to_dict())
				
				if stop.timestamp != timestamp:
					stop.timestamp = timestamp
					stop.cost = -1
					stop.graph_id = -1
				
				if pair[1].is_target and not pair[1] in accounting:
					targets.append(pair[1])
					accounting[pair[1]] = Crawler.new(pair[1])
					stop.cost = 0
				else:
					var altern = start.cost + pair[1].get_weight(orig, pair[0]) if internal else stop.weight
					if stop.cost < 0:
						stop.cost = altern
					else:
						stop.cost = min(stop.cost, altern)
				if internal: from_network(pair[1])
	
	for orig in accounting:
		for node in accounting[orig].excluded:
			var info = network.get_or_add(node, node.to_dict())
			if info.timestamp == timestamp: continue
			info.timestamp = timestamp
			info.cost = -1
			info.graph_id = -1
			if internal: from_network(node)
	return accounting


## Updates [code]graph_id[/code] in [code]network[/code] to distinguish each node's
## graph. It uses the dictionary returned by [code]baking()[/code] and will call
## [code]graphs_mapped()[/code] after it's done.[br]
## Graphs are interconnected nodes in a network, disconnected from nodes of another graph.[br]
## It returns an array of node lists, each list representing a graph, with all
## owners of the nodes included in the graph. If there's no owner the node itself
## is added.[br]
## Optionally also update the node's [code]internal[/code] value.
func find_network_graphs(queries:Dictionary[DijkstraNode, Crawler], internal:=false) -> Array[Array]:
	var graphs :  Array[Array]
	var accounted : Array[DijkstraNode]
	for endpoint in queries:
		var all = queries[endpoint].nodes + [endpoint]
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


## Run a search through all connections in target nodes in [code]these[/code].
## If they aren't endpoints, meaning that [code]DijkstraNode.is_target[/code] is
## [code]false[/code], then It first searches an endpoint leading to them, which
## will slowdown the opeartion.[br]
## Novel endpoints discovered along the way initiate further searches, but from
## the time of discovery, rather than at beginning of the call.[br]
## Use [code]find_graphs()[/code] to update [code]DijkstraNode.graph_id[/code].[br]
## This returns a Dictionary where the keys are endpoints and the values are their
## Crawler instances, with information of found nodes.
static func mapping(...these) -> Dictionary[DijkstraNode, Crawler]:
	@warning_ignore("shadowed_variable")
	var timestamp : int = Time.get_ticks_usec()
	var accounting : Dictionary[DijkstraNode, Crawler]
	
	# Sanitation and categorization
	var sieved = sieve_nodes.callv(these)
	
	for node : DijkstraNode in sieved[0]:
		node.timestamp = timestamp
		node.cost = 0
		node.graph_id = -1
		accounting[node] = Crawler.new(node)
	for node : DijkstraNode in seek_endpoints(sieved[1]):
		if not node in accounting:
			node.timestamp = timestamp
			node.cost = 0
			node.graph_id = -1
			accounting[node] = Crawler.new(node)
	if accounting.is_empty():
		return {}
	
	var halt := false
	while halt == false:
		halt = true
		for orig in accounting:
			var crawl = accounting[orig]
			if not crawl.is_finished(): halt = false
			for pair : Array[DijkstraNode] in crawl.iterate(SEEK.LINKS):
				if pair[1].timestamp != timestamp:
					pair[1].timestamp = timestamp
					pair[1].cost = -1
					pair[1].graph_id = -1
				
				if pair[1].is_target and not pair[1] in accounting:
					accounting[pair[1]] = Crawler.new(pair[1])
					pair[1].cost = 0
				else:
					var altern = pair[0].cost + pair[1].get_weight(orig, pair[0])
					if pair[1].cost < 0:
						pair[1].cost = altern
					else:
						pair[1].cost = min(pair[1].cost, altern)
	return accounting


## Updates [code]graph_id[/code] in [code]DijsktraNode[/code] to distinguish each node's
## graph. It uses the dictionary returned by [code]mapping()[/code] and if
## [code]notify_mapped[/code] is [code]true[/code], will call
## [code]DijkstraNode.graphs_mapped()[/code] on each node.[br]
## Graphs are interconnected nodes in a network, disconnected from nodes of another graph.[br]
## It returns an array of node lists, each list representing a graph, with all
## owners of the nodes included in the graph. If there's no owner the node itself
## is added.[br]
static func find_graphs(queries:Dictionary[DijkstraNode, Crawler], notify_mapped:=true) -> Array[Array]:
	var graphs :  Array[Array]
	var accounted : Array[DijkstraNode]
	for endpoint in queries:
		var all = queries[endpoint].nodes + [endpoint]
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
			if not node in endpoints:
				endpoints.append(node)
		elif not node in other:
			other.append(node)
	return [endpoints, other]


## Given a selection of nodes, finds the endpoints of the same graph as them.
## If endpoints are provided, they are including in the returned list, but don't
## initiate a search.[br]
## NOTE: This uses the [code]Crawler[/code] iterator and doesn't rely on mapping.[br]
## This makes it robust against outdated or indeterminate graphs.[br]
## Use [code]search()[/code] to find the endpoint leading to a node using the
## pre-computed costs in mapping, which is a faster operation.
static func seek_endpoints(...these) -> Array[DijkstraNode]:
	var sieved = sieve_nodes.callv(these)
	var endpoints : Array[DijkstraNode] = sieved[0]
	for endpoint in sieved[1]:
		var finds = Crawler.new(endpoint).all_iterate(SEEK.NODES, sieved[0])
		for node : DijkstraNode in finds[1]:
			if node.is_target and not node in endpoints:
				endpoints.append(node)
	return endpoints


## After computing travel costs of nodes with [code]mapping()[/code],
## this returns the owners of nodes from [code]from[/code] along the way with 
## the least cost until a target is found. 
## If nodes have no owner, we return the node itself.[br]
## The order of returned objects follows the path found to the target.
## If the target can't be found, returns partial path, if told to.[br]
## Nodes that refuse connection during [code]mapping()[/code] will be avoided,
## but [code]from[/code] node is not affected by this.[br]
static func travel(from:DijkstraNode, partial:=false) -> Array:
	var curr : DijkstraNode = from
	var path : Array[DijkstraNode] = [from]
	while not curr.is_target:
		var naibaro = curr.get_connections(null, curr)
		naibaro = naibaro.filter(func(a): return a.cost >= 0 and not a in path)
		naibaro.sort_custom(func(a, b): return a.cost <= b.cost)
		curr = naibaro.front()
		path.append(curr)
	
	if not (path.back().is_target or partial):
		# The last node is not a target and we don't want partial paths.
		return []
	
	var path_owners : Array
	for node in path:
		path_owners.append( node if node.owner == null else node.owner )
	return path_owners

## Finds a path away from the closest node until the edge of a
## region is found. Regions are sets of nodes in a graph, with a common endpoint
## as their closest.
static func inverse_travel(from:DijkstraNode) -> Array:
	var curr : DijkstraNode = from
	var path : Array[DijkstraNode] = [from]
	while not curr.is_target:
		var naibaro = curr.get_connections(null, curr)
		naibaro = naibaro.filter(func(a): return a.cost >= 0 and a.cost >= curr.cost and not a in path)
		if naibaro.size() == 0:
			break
		naibaro.sort_custom(func(a, b): return a.cost > b.cost)
		curr = naibaro.front()
		path.append(curr)
	
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
	var search1 = travel(bridge1)
	search1.reverse()  # Make the path from the endpoint to the bridge
	return search1 + travel(bridge2)  # endpoint1 -> bridge1 -> bridge2 -> endpoint2

## Find if the two nodes are in the same region.
## Nodes of the same regions have a common target node as the closest to them.[br]
static func same_region(node1:DijkstraNode, node2:DijkstraNode) -> bool:
	var path1 = travel(node1)
	var path2 = travel(node2)
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
