extends xNetBase
class_name xNetAnalysis

## Functions necessary to traverse, search and analyze a network.


class xCrawler:
	## Travels through the network in steps, returning things of interest that it finds.[br]
	## It starts travel from all given [code]origins[/code] in parallel and can
	## travel by Breadth-First Search and Depth-First Search.
	
	var orig : Array[xNetNode]
	var history : Dictionary[xNetNode, xNetNode]  ## Nodes from which a node in the keys was found from.
	var visited : Dictionary[xNetNode, Array]  ## Tracking connections already checked. Given a node as key, it returns nodes that which connections to we've explored.
	var all_visited : Array[xNetNode]  ## Nodes which all acceptable connections have been visited.
	var queue : Array[xNetNode]  ## The traversal queue, where nodes to visit are placed.
	var finds : Array[xNetNode]  ## The items of interest found along the search. It might have duplicates, if the same finding is repeated.
	var iter_finds : Array[xNetNode]  ## The items of interest found on the last search iteration.
	var _head : int  # Pointer of `queue`: nodes behind can't be visited again, ahead are yet to visit.
	func _init(origins:Array[xNetNode]) -> void:
		orig.assign(origins)
		queue = orig.duplicate()
		for each in origins:
			history[each] = null
	
	## In case you want to a search anew, without losing finds so far. It won't clear
	## previous finds, nor history, but it will be overwritten with further iterations.[br]
	## NOTE: This will allow previously visited nodes to be visited again.
	func reset():
		visited.clear()
		all_visited.clear()
		queue = orig.duplicate()
		_head = 0
	
	## Returns whether there are nodes to search, even if they aren't what's being searched.
	func is_finished() -> bool:
		return queue.is_empty() or _head >= queue.size()
	
	## [code]from[/code] a node in [code]finds[/code], return the chain of nodes back
	## into its search origin. Both the origin and [code]from[/code] are included.
	func search_path(from:xNetNode) -> Array[xNetNode]:
		var source = history.get(from)
		if source == null: return [from]
		var chain : Array[xNetNode] = [from, source]
		while not source in orig:
			if history.get(chain.back()) == null: break  # Can't find path. Return partial path
			source = history[chain.back()]
			chain.append(source)
		return chain
	
	## Returns whether the [code]next[/code] node is of interest to visit.
	func _conn_accept(curr:xNetNode, next:xNetNode, node_accept:=Callable()) -> bool:
		if next in queue: return false  # Already accounted for visiting later.
		if next in all_visited: return false  # Nothing more to explore in this node.
		if next in visited.get(curr, []): return false  # Connection already tried.
		if not node_accept.is_valid() or node_accept.call(curr, next): return true
		return false  # Failed the `node_accept` test.
	
	## Iterate one step in Depth-First Search. You may supply a function to decide
	## whether a node is worth exploring further, and a function to decide if a
	## node along the way is of interest to return. If the Callables are invalid,
	## it assumes we want to accept and find any node. The functions must take
	## the arguments for current node being visited and the next own being checked
	## due the current one connecting to it.[br]
	## It returns all the finds of interest in a given iteration call, but can
	## also be accessed from [code]iter_finds[code]. All finds ever made are
	## stored in [code]finds[/code].
	func depth_traverse(node_accept:=Callable(), node_find:=Callable()) -> Array[xNetNode]:
		iter_finds.clear()
		if queue.is_empty(): return []
		
		var curr = queue.back()
		var prev = history[curr]
		for next in curr.get_connections(prev):
			if _conn_accept(curr, next, node_accept):
				visited.get_or_add(curr, []).append(next)
				history[next] = curr
				queue.push_back(next)
				if not node_find.is_valid() or node_find.call(curr, next):
					# Is item of interest to return. Because we are only taking one node from all connections, we can't wait to pick other connections for finds.
					iter_finds.append(next)
				break  # In depth first search we only care about the first valid connection we find. At a later time we explore alternatives.
		
		if iter_finds.is_empty():
			all_visited.append(queue.pop_back())
		finds.append_array(iter_finds)
		return iter_finds
	
	func breadth_traverse(node_accept:=Callable(), node_find:=Callable()) -> Array[xNetNode]:
		iter_finds.clear()
		for curr in queue.slice(_head, queue.size()):
			_head += 1
			all_visited.append(curr)
			var prev = history[curr]
			for next in curr.get_connections(prev):
				if not node_find.is_valid() or node_find.call(curr, next):
					# Is item of interest to return, doesn't mean it's an item we want to visit.
					if not next in queue and not next in finds:
						iter_finds.append(next)
						history[next] = curr
				if _conn_accept(curr, next, node_accept):
					history[next] = curr
					visited.get_or_add(next, []).append(curr)
					queue.push_back(next)
		
		finds.append_array(iter_finds)
		return iter_finds


## Traverse the whole graphs connected to [code]origins[/code], setting
## [code]xNetNode.dist[/code] of nodes found along the way.[br]
## Returns all the xCrawlers used to map the network that can be fed into
## [code]find_graphs()[/code] to discriminate distinct graphs of isolated nodes.
func build_flow_field(...origins) -> Array[xCrawler]:
	var crawls : Array[xCrawler]
	var more_crawls : Array[xNetNode]
	more_crawls.assign(origins)
	var finished = false
	while not finished:
		if not more_crawls.is_empty():
			crawls.append(xCrawler.new(more_crawls))
			more_crawls.clear()
		for craw in crawls:
			if craw.is_finished():
				finished = true
			for node in craw.breadth_traverse():
				if node.pin:
					node.dist = 0
					if not node in origins:
						origins.append(node)
						more_crawls.append(node)
				else:
					var dist = craw.history[node].dist + 1
					if node.dist <= 0: node.dist = dist
					else: node.dist = min(node.dist, dist)
	return crawls


## Returns an array for each graph in the network that can be discriminated
## from [code]crawlers[/code].
func find_graphs(...crawlers) -> Array[Array]:
	var graphs : Array[Array]
	var accounted : Array[xNetNode]
	for crawl : xCrawler in crawlers:
		var all = crawl.orig + crawl.finds
		for node in all:
			if not node in accounted:
				graphs.append(all)
				accounted.append_array(all)
				break
	return graphs


## Traverse the given nodes in [code]paths[/code], updating the [code]xNetNode.dist[/code], assuming the
## first elements of each array have correct values and further elements are nodes of raising distance.[br]
## The traversal along some path will quit early if it can't lower the cost at some point.
func update_flow_field(paths:Array[Array]):
	var last : Array[int]  # The distance of the last node updated
	for each in paths:
		each.reverse()
		last.append(each.pop_back().dist)
	while not paths.is_empty():
		var p : int = 0
		for each in paths.size():
			var node : xNetNode = paths[p].pop_back()
			var dist = last[p] + 1
			if node.dist <= 0 or node.pin == true:
				if node.pin == true: node.dist = 0
				else: node.dist = dist
			else:
				node.dist = min(last[p] + 1, node.dist)
				
			if node.dist < last[p] or paths[p].is_empty():
				paths.remove_at(p)
				last.remove_at(p)
			else:
				last[p] = node.dist
				p += 1


## Follows the flow field to find a node with [code]xNetNode.pin[/code] set
## [code]true[/code], then returns the path of nodes found along the way.[br]
## NOTE, this search can explore out of [code]from[/code] if its [code]xNetNode.dist[/code]
## is negative, but won't continue past further nodes of negative value.
func flow_search(from:xNetNode) -> Array[xNetNode]:
	var rule = Callable(func(curr, next): return (curr.dist == -1 or curr.dist > next.dist) and next.dist >= 0)
	var crawl := xCrawler.new([from])
	while not crawl.is_finished():
		crawl.depth_traverse(rule, rule)
		var last = crawl.finds.back()
		if last != null and last.pin == true: break
	if crawl.finds.is_empty():
		return [from]
	return crawl.search_path(crawl.finds.back())
