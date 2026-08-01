extends xNetAnalysis
class_name xNetwork

## The Network uses an interchangeable Netlist which stores all the information needed
## to reconstruct graphs. A network being defined as a collection of graphs, where
## vertices in a graph are isolated from vertices of other graphs.[br]
## This class doesn't provide ways to determinate which vertices are in the same graph,
## but includes a Crawler and function that can be used to figure that out.[br]
## In NetData, the resource of the netlist, connections (graph edges) are represented
## by pairs of vertices. The hashes of these vertices undergo a XOR operation returning
## a unique hash (or ID) for each connection. That ID is then the key of a Dictionary
## to a Wire object which is intended to be queried when drawing on screen.[br]
## If the directionality of the connection is important (like when deciding which
## vert to draw a Wire from), NetData containt a Dictionary that takes a connection
## ID and returns the pair of verts, the first being the origin of a connection.
## This can also be used to quickly tell which verts are between the connection.[br]
## If a vert in a connection is known, it's also possible to find the other one
## by performing a XOR operation of the vert hash and the connection ID. The
## resulting hash can be used as a key to find the other vert.


var netlist : xNetData

func _init() -> void:
	if netlist == null:
		netlist = xNetData.new()

class xNetData extends Resource:
	## We have network elements in here, so they can be serialized and interchanged
	## with loading and saving.
	@export_storage var vias : Dictionary[Vector2i, xNetVert]  ## This is an index of verts that can be used to search them by grid coordinate.
	@export_storage var verts : Dictionary[int, xNetVert]  ## The hash of each vert.
	@export_storage var pairs : Dictionary[int, Array]  ## The hash of a connection to the pair of verts it relates to.
	@export_storage var links : Dictionary[int, xWire]  ## The hash of a connection to a Wire object, used to draw that connection on screen.


## Return the verts the given one leads to. Optionally you may select whether to
## get only those originating [code]vert[/code] or ending in it.
func get_connections(vert:xNetVert, outgoing:=true, ingoing:=true) -> Array[xNetVert]:
	var conns : Array[xNetVert]
	var max_count = vert.size()
	var count : int = 0
	for pair_hash in netlist.pairs:
		var pair = netlist.pairs[pair_hash]
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
func get_links(vert:xNetVert, outgoing:=true, ingoing:=true) -> PackedInt64Array:
	var conns : Array[int]
	var max_count = vert.size()
	var count : int = 0
	for pair_hash in netlist.pairs:
		var pair = netlist.pairs[pair_hash]
		if vert in pair:
			count += 1
			if (pair[0] == vert and outgoing) or (pair[1] == vert and ingoing):
				conns.append(pair_hash)
		if count >= max_count: break
	return conns


func get_or_add_vert(coord:Vector2i, new_vert:xNetVert) -> xNetVert:
	if coord in netlist.vias:
		return netlist.vias[coord]
	
	netlist.vias[coord] = new_vert
	new_vert.coord = coord
	
	var id = hash(new_vert)
	netlist.verts[id] = new_vert
	return new_vert

func rem_vert_at(coord:Vector2i):
	var vert = netlist.vias.get(coord)
	if vert == null: return
	rem_vert(vert)

func rem_vert(vert:xNetVert):
	var conns = get_links(vert)
	var id = hash(vert)
	for pair_hash in conns:
		netlist.links.erase(pair_hash)
		netlist.pairs.erase(pair_hash)
	netlist.vias.erase(vert.coord)
	netlist.verts.erase(id)

func make_pair_hash(j1:xNetVert, j2:xNetVert) -> int:
	return hash(j1) ^ hash(j2)

func make_link(j1:xNetVert, j2:xNetVert, link:xWire):
	var pair = make_pair_hash(j1, j2)
	netlist.pairs[pair] = [j1, j2]
	netlist.links[pair] = link
	j1.connecter(j2)
	j2.connectee(j1)

func rem_link_verts(j1:xNetVert, j2:xNetVert):
	rem_link_hash(make_pair_hash(j1, j2))

func rem_link_hash(pair_hash:int):
	if not pair_hash in netlist.links: return
	var conns = netlist.pairs[pair_hash]
	netlist.links.erase(pair_hash)
	netlist.pairs.erase(pair_hash)
	conns[0].disconnected(conns[1])
	conns[1].disconnected(conns[0])
