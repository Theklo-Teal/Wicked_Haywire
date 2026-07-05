extends xNetBase
class_name xNetAnalysis

## Functions necessary to traverse, search and analyze a network.


class xCrawler:
	## Travels through the network in steps, returning things of interest that it finds.[br]
	## It starts travel from all given [code]origins[/code] in parallel and can
	## travel by Breadth-First Search and Depth-First Search.
	
	var orig : Array[xNetNode]
	var root : Dictionary[xNetNode, xNetNode]  ## The node in [code]orig[/code] that originated a path towards finding any other given node. Origin nodes point to themselves.
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
			root[each] = each
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
						history[next] = curr
						root[next] = root[curr]
						iter_finds.append(next)
				if _conn_accept(curr, next, node_accept):
					history[next] = curr
					root[next] = root[curr]
					visited.get_or_add(next, []).append(curr)
					queue.push_back(next)
		
		finds.append_array(iter_finds)
		return iter_finds


## Finds the closest graph target to a given node and sets its [code]xNetNode.endnode[/code].
func seek_endnode(from:xNetNode) -> xJoint:
	if from is xJoint:
		from.endnode = null
		return from
	var crawl = xCrawler.new([from])
	while crawl.breadth_traverse(Callable(), func(_curr,next): return next is xJoint).is_empty() and not crawl.is_finished():
		continue
	from.endnode = crawl.finds.back()
	return from.endnode

## Traverse the whole graphs connected to [code]origins[/code], setting
## [code]xNetNode.distan[/code] and [code]xNetNode.endnode[/code] of nodes found
## along the way.[br]
## Returns all the xCrawlers used to map the network that can be fed into
## [code]find_graphs()[/code] to discriminate distinct graphs of isolated nodes.
func build_flow_field(...origins) -> Array[xCrawler]:
	var timestamp = Time.get_ticks_usec()
	var crawls : Array[xCrawler]
	var add_crawls : Array[xNetNode]
	for node in origins:
		if node is xJoint:
			node.timestamp = timestamp
			node.endnode = null
			add_crawls.append(node)
		else:
			var endnode = seek_endnode(node)
			if endnode != null: add_crawls.append(endnode)
	var finished = false
	while not finished:
		if not add_crawls.is_empty():
			crawls.append(xCrawler.new(add_crawls))
			add_crawls.clear()
		for craw in crawls:
			if craw.is_finished():
				finished = true
			for node in craw.breadth_traverse():
				node.timestamp = timestamp
				if node is xJoint:
					node.distan = 0
					node.endnode = null
					if not node in origins:
						origins.append(node)
						add_crawls.append(node)
				else:
					var dist = craw.history[node].distan + 1
					node.endnode = craw.root[node]
					if node.distan <= 0: node.distan = dist
					else: node.distan = min(node.distan, dist)
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


## Traverse the given nodes in [code]paths[/code], updating the
## [code]xNetNode.distan[/code] and [code]xNetNode.endnode[/code], assuming the
## first elements of each array have correct values and further elements are
## nodes of raising distance.[br]
## The traversal along some path will quit early if it can't lower the cost at
## some point.
func update_flow_field(paths:Array[Array]):
	var timestamp = Time.get_ticks_usec()
	var last : Array[int]  # The distance of the last node updated
	var firsts : Array[xNetNode]
	for each in paths:
		each.reverse()
		var firstnode = each.pop_back()
		firstnode.timestamp = timestamp
		firsts.append(firstnode)
		last.append(firstnode.distan)
	while not paths.is_empty():
		var p : int = 0
		for each in paths.size():
			var node : xNetNode = paths[p].pop_back()
			node.timestamp = timestamp
			if node is xJoint:
				node.endnode = null
				node.distan = 0
			else:
				var dist = last[p] + 1
				node.endnode = firsts[p]
				if node.distan <= 0:
					node.distan = dist
				else:
					node.distan = min(last[p] + 1, node.distan)
				
			if node.distan < last[p] or paths[p].is_empty():
				paths.remove_at(p)
				last.remove_at(p)
			else:
				last[p] = node.distan
				p += 1


## Follows the flow field to find a node that is [code]xJoint[/code], then returns 
## the path of nodes found along the way.[br]
## If an xJoint can't be found, it returns a partial path.
## NOTE, this search can explore out of [code]from[/code] if its [code]xNetNode.distan[/code]
## is negative, but won't continue past further nodes of negative value.
func flow_search(from:xNetNode) -> Array[xNetNode]:
	var rule = Callable(func(curr, next): return (curr.distan == -1 or curr.distan > next.distan) and next.distan >= 0)
	var crawl := xCrawler.new([from])
	while crawl.breadth_traverse(rule, func(_curr, next):return next is xJoint).is_empty() and not crawl.is_finished():
		continue
	if crawl.finds.is_empty():
		return [from]
	return crawl.search_path(crawl.finds.back())  # If multiple joints are found, we just care about one of them.
