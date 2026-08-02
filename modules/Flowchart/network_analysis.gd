@abstract
extends NetBase
class_name NetAnalysis

## Functions necessary to store, traverse, search and analyze a network.

func make_pair_hash(v1:NetVert, v2:NetVert) -> int:
	return hash(v1) ^ hash(v2)

class NetData extends Resource:
	## We have network elements in here, so they can be serialized and interchanged
	## with loading and saving.
	@export_storage var vias : Dictionary[Vector3i, NetVert]  ## For free standing joints.
	@export_storage var verts : Dictionary[int, NetVert]  ## Find joint from their hashes.
	@export_storage var pairs : Dictionary[int, Array]  ## The link hash according to the joints involved. The order encodes the orientation of the link.
	@export_storage var links : Dictionary[int, Link]  ## The key is the XOR of hashes of two joints. The value is the Link instance representing that. 	
	@export_storage var gizmos : Dictionary[int, Array]  ## An array of Gizmo for a given layer.
	@export_storage var sockets : Dictionary[NetVert, FlowchartGizmo]  ## Which Gizmo are sockets found?

	## Return the verts the given one leads to. Optionally you may select whether to
	## get only those originating [code]vert[/code] or ending in it.
	func get_connections(vert:NetVert, outgoing:=true, ingoing:=true) -> Array[NetVert]:
		var conns : Array[NetVert]
		var max_count = vert.conns()
		var count : int = 0
		for pair_hash in pairs:
			var pair = pairs[pair_hash]
			if vert in pair:
				count += 1
				if (pair[0] == vert and outgoing):
					conns.append(pair[1])
				elif (pair[1] == vert and ingoing):
					conns.append(pair[0])
			if count >= max_count: break
		return conns

	## Return the pair hashes of connections to the given vert. Optionally you may
	## select whether to get only those originating [code]vert[/code] or ending in it.
	func get_links(vert:NetVert, outgoing:=true, ingoing:=true) -> PackedInt64Array:
		var conns : Array[int]
		var max_count = vert.conns()
		var count : int = 0
		for pair_hash in pairs:
			var pair = pairs[pair_hash]
			if vert in pair:
				count += 1
				if (pair[0] == vert and outgoing) or (pair[1] == vert and ingoing):
					conns.append(pair_hash)
			if count >= max_count: break
		return conns

	## Given a pair hash, what's the other joint of the pair?[br]
	## Returns [code]null[/code] if the hash is invalid or the joint can't be found.
	func link_of(vert:NetVert, pair_hash:int) -> NetVert:
		if not pair_hash in links: return null
		return verts.get(hash(vert) ^ pair_hash, null)

class Crawler:
	## Travels through the network in steps, returning things of interest that it finds.[br]
	## It starts travel from all given [code]origins[/code] in parallel and can
	## travel by Breadth-First Search and Depth-First Search.
	
	var net : NetData
	var orig : Array[NetVert]
	var root : Dictionary[NetVert, NetVert]  ## The vert in [code]orig[/code] that originated a path towards finding any other given vert. Origin verts point to themselves.
	var history : Dictionary[NetVert, NetVert]  ## Verts from which a vert in the keys was found from.
	var visited : Dictionary[NetVert, Array]  ## Tracking connections already checked. Given a vert as key, it returns nodes that which connections to we've explored.
	var all_visited : Array[NetVert]  ## Verts which all acceptable connections have been visited.
	var queue : Array[NetVert]  ## The traversal queue, where nodes to visit are placed.
	var finds : Array[NetVert]  ## The items of interest found along the search. It might have duplicates, if the same finding is repeated.
	var iter_finds : Array[NetVert]  ## The items of interest found on the last search iteration.
	var _head : int  # Pointer of `queue`: nodes behind can't be visited again, ahead are yet to visit.
	
	func _init(netlist:NetData, origins:Array[NetVert]) -> void:
		net = netlist
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
	
	
	## [code]from[/code] a Vert in [code]finds[/code], return the chain of Verts back
	## into its search origin. Both the origin and [code]from[/code] are included.
	func search_path(from:NetVert) -> Array[NetVert]:
		var source = history.get(from)
		if source == null: return [from]
		var chain : Array[NetVert] = [from, source]
		while not source in orig:
			if history.get(chain.back()) == null: break  # Can't find path. Return partial path
			source = history[chain.back()]
			chain.append(source)
		return chain
	
	## Returns whether the [code]next[/code] Vert is of interest to visit.
	func _conn_accept(curr:NetVert, next:NetVert, vert_accept:=Callable()) -> bool:
		if next in queue: return false  # Already accounted for visiting later.
		if next in all_visited: return false  # Nothing more to explore in this node.
		if next in visited.get(curr, []): return false  # Connection already tried.
		if not vert_accept.is_valid() or vert_accept.call(curr, next): return true
		return false  # Failed the `vert_accept` test.
	
	## Iterate one step in Depth-First Search. You may supply a function to decide
	## whether a Vert is worth exploring further, and a function to decide if a
	## Vert along the way is of interest to return. If the Callables are invalid,
	## it assumes we want to accept and find any Vert. The functions must take
	## the arguments for current Vert being visited and the next own being checked
	## due the current one connecting to it.[br]
	## It returns all the finds of interest in a given iteration call, but can
	## also be accessed from [code]iter_finds[code]. All finds ever made are
	## stored in [code]finds[/code].
	func depth_traverse(vert_accept:=Callable(), vert_find:=Callable()) -> Array[NetVert]:
		iter_finds.clear()
		if queue.is_empty(): return []
		var curr = queue.back()
		#var prev = history[curr]
		for next in net.get_connections(curr):
			if _conn_accept(curr, next, vert_accept):
				visited.get_or_add(curr, []).append(next)
				history[next] = curr
				queue.push_back(next)
				if not vert_find.is_valid() or vert_find.call(curr, next):
					# Is item of interest to return. Because we are only taking one vert from all connections, we can't wait to pick other connections for finds.
					iter_finds.append(next)
				break  # In depth first search we only care about the first valid connection we find. At a later time we explore alternatives.
		
		if iter_finds.is_empty():
			all_visited.append(queue.pop_back())
		finds.append_array(iter_finds)
		return iter_finds
	
	func breadth_traverse(vert_accept:=Callable(), vert_find:=Callable()) -> Array[NetVert]:
		iter_finds.clear()
		for curr in queue.slice(_head, queue.size()):
			_head += 1
			all_visited.append(curr)
			#var prev = history[curr]
			for next in net.get_connections(curr):
				if not vert_find.is_valid() or vert_find.call(curr, next):
					# Is item of interest to return, doesn't mean it's an item we want to visit.
					if not next in queue and not next in finds:
						history[next] = curr
						root[next] = root[curr]
						iter_finds.append(next)
				if _conn_accept(curr, next, vert_accept):
					history[next] = curr
					root[next] = root[curr]
					visited.get_or_add(next, []).append(curr)
					queue.push_back(next)
		
		finds.append_array(iter_finds)
		return iter_finds


## Returns an array for each graph in the network that can be discriminated
## from [code]crawlers[/code].
func find_graphs(...crawlers) -> Array[Array]:
	var graphs : Array[Array]
	var accounted : Array[NetVert]
	for crawl : Crawler in crawlers:
		var all = crawl.orig + crawl.finds
		for node in all:
			if not node in accounted:
				graphs.append(all)
				accounted.append_array(all)
				break
	return graphs
