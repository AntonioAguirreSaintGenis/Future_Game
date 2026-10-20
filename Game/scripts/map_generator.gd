extends TileMap

@onready var player = $Player
@onready var camera = $Player/Camera2D

const DOOR_TILE = Vector2i(0, 1)
const SIDES = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const MAX_LAYERS = 5      # a side gets between MIN_LAYERS and MAX_LAYERS layers
const MIN_LAYERS = 2

const SKIP_CHANCE = 0.05#0.035
const SKIP_CHANCE_ONE_EMPTY = 0.95
const SKIP_CHANCE_MANY_EMPTY =  0.25

const CAM_SPEED_NORMAL = 25.0      # follow speed inside a room
const CAM_SPEED_TRANSITION = 5.0   # glide speed after changing region
const CAM_TRANSITION_TIME = 0.7

var obstacles = {}
var CARDINAL = ["NORTH", "SOUTH", "EAST", "WEST"]
var map = [] #the main matrix, where rooms will be placed.
var region_map = [] #stores wich rooms belong together to form big rooms.
var zone_map = [] #stores wich rooms belong to wich zone.
var visited = []
var NB_ZONES = 8 
var HEIGHT = 40 #size of the map
var WIDTH = 40 #size of the map
var TARGET_ROOMS = 250 #number of rooms
var drunkards = [] #here will be placed all drunkards that
#will move randomly to create the layout of the map.
var NB_DRUNKARDS = 5
var rooms_placed
var direction
var rng = RandomNumberGenerator.new()
var nb_rooms = 0
var room_size = 20
var skip_streaks = []  # consecutive skipped tiles right before the current one
var current_room = Vector2i(-1, -1)
var region_bounds = {}  # region id -> Rect2i in cell coords
var current_region = -2
var camera_tween: Tween
var region_rect = Rect2()
var transition_left = 0.0
var big_rooms = {}
var doors = {}


func _ready():
	rng.randomize()
	for i in range(NB_DRUNKARDS):
		#creates all the drunkards. The first 0 corresponds to the x value,
		#the second to the y value.
		drunkards.append([0, 0, int(TARGET_ROOMS/NB_DRUNKARDS)])
	for i in range(HEIGHT):
		#creates the vertical columns for the matrices
		map.append([])
		region_map.append([])
		zone_map.append([])
		visited.append([])
		for j in range(WIDTH):
			#creates the rows. Map is 0 because the number in the map
			#corresponds with the number of times a drunkard passed by,
			#the rest are -1 because they have no value yet.
			map[i].append(0)
			visited[i].append(false)
			zone_map[i].append(-1)
			region_map[i].append(-1)
	var coords
	for i in range(len(drunkards)):
		#creation of the layout, the drunkards are placed on borders
		#to try to make the layout less compact.
		#The drunkards move randomly to one of the cardinal directions.
		rooms_placed = 0
		coords = choose_border(map)
		drunkards[i][0] = coords[0]
		drunkards[i][1] = coords[1]
		while rooms_placed < drunkards[i][2]:
			if (map[drunkards[i][1]][drunkards[i][0]]) == 0:
				rooms_placed += 1
			map[drunkards[i][1]][drunkards[i][0]] += 1
			direction = CARDINAL[rng.randi_range(0, len(CARDINAL) - 1)]
			if direction == "NORTH" and drunkards[i][1] > 0:
				drunkards[i][1] -= 1
			elif direction == "SOUTH" and drunkards[i][1] < HEIGHT-1:
				drunkards[i][1] += 1
			elif direction == "WEST" and drunkards[i][0] > 0:
				drunkards[i][0] -= 1
			elif direction == "EAST" and drunkards[i][0] < WIDTH-1:
				drunkards[i][0] += 1
	var candidates = flood_fill_zones(map, visited)
	compute_region_bounds()
	var group_edges = candidates[1]
	player.position = map_to_local(Vector2(candidates[2][0] * room_size + MAX_LAYERS, candidates[2][1] * room_size + MAX_LAYERS))
	candidates = candidates[0]
	doors = randomized_kruskal(map, group_edges)
	#var edges = zone_edges()
	apply_zones_to_tiles(candidates, doors)
	
	#draw empty tiles
	for y in range(HEIGHT):
		for x in range(WIDTH):
			if map[y][x] == 0:
				for ty in range(room_size):
					for tx in range(room_size):
						set_cell(0,Vector2i(x * room_size + tx, y * room_size + ty),0,Vector2i(1, 1))
	#set_cell(0, Vector2i(0, 0), 0, Vector2i(7, 0))
	#print_map(map)

func _physics_process(_delta):
	var cell = get_room_of(player.global_position)
	if cell.x < 0 or cell.y < 0 or cell.x >= WIDTH or cell.y >= HEIGHT:
		return
	var region = region_map[cell.y][cell.x]
	if region != current_region and region_bounds.has(region):
		current_region = region
		update_camera_limits(region_bounds[region])

func get_room_of(global_pos: Vector2) -> Vector2i:
	var tile = local_to_map(to_local(global_pos))
	# floori so it still behaves if the player ever goes into negative coords
	return Vector2i(floori(float(tile.x) / room_size), floori(float(tile.y) / room_size))

func update_camera_limits(bounds: Rect2i) -> void:
	var tile_px = Vector2(tile_set.tile_size)
	var top_left = to_global(Vector2(bounds.position * room_size) * tile_px)
	var bottom_right = to_global(Vector2(bounds.end * room_size) * tile_px)
	# First call: snap, because the default limits are +/-10,000,000
	"""var duration = 0.7 if camera_tween else 0.0
	if camera_tween:
		camera_tween.kill()
	camera_tween = create_tween().set_parallel(true)
	camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(camera, "limit_left", int(top_left.x), duration)
	camera_tween.tween_property(camera, "limit_top", int(top_left.y), duration)
	camera_tween.tween_property(camera, "limit_right", int(bottom_right.x), duration)
	camera_tween.tween_property(camera, "limit_bottom", int(bottom_right.y), duration)"""
	#camera.position_smoothing_speed = 2
	camera.limit_left = int(top_left.x)
	camera.limit_top = int(top_left.y)
	camera.limit_right = int(bottom_right.x)
	camera.limit_bottom = int(bottom_right.y)


func apply_zones_to_tiles(candidates, T):
	#This function calls the function to draw each room.
	#Candidates correspond to all (x, y) position in map
	#that corresponds to a room.
	#T stores the doors between rooms.
	for i in candidates:
		var zone = zone_map[i[1]][i[0]]
		create_room(i[0], i[1], zone_map[i[1]][i[0]], room_size, T)
				
func flood_fill_zones(map, visited_original):
	#This functions gives a zone to each (x, y) position in the map that
	#is not 0.
	var zone_sizes = [] #the size of each zone.
	var zone_queues = [] #the starting point of each zone + all new nodes.
	var groups_edges = [] #all edges separeted by region they belong.
	var region_cells = [] #all cells belonging to each region, indexed by region id.
	var zone_0 #the starting room for the game.
	var next_region = 0
	var visited = visited_original.duplicate(true)
	var region #the id for each room. Usefull to give the value to region_map.

	# init
	for i in range(NB_ZONES):
		#there is no node for the zones at the begining, so their size is 0.
		#returns a list of size 3 that contains the nodes that are rooms (candidates)
		#in the map, the group_edges, and the starting location for the game.
		zone_queues.append([])
		zone_sizes.append(0)

	var candidates = []
	for y in range(HEIGHT):
		for x in range(WIDTH):
			if map[y][x] > 0:
				#if map[y][x] is not 0, then it's a room.
				candidates.append([x, y])
			if visited[y][x]:
				continue
			if map[y][x] == 0:
				continue
			region = next_region #updates the id.
			next_region += 1
			var value = map[y][x]
			var zone = zone_map[y][x]
			var queue = []
			var edges = []
			queue.append([x, y])
			visited[y][x] = true
			region_map[y][x] = region
			# to avoid duplicate edges inside same component
			var edge_set = {}
			var head = 0
			#we want to find the big rooms. Something is part of a big room if
			#all adjacent (x, y) positions in map have the same number as them.
			while head < queue.size():
				var cell = queue[head]
				head += 1
				var cx = cell[0]
				var cy = cell[1]
				for dir in [[1,0], [-1,0], [0,1], [0,-1]]:
					var nx = cx + dir[0]
					var ny = cy + dir[1]
					if nx < 0 or nx >= WIDTH or ny < 0 or ny >= HEIGHT:
						continue
					if map[ny][nx] != value or zone_map[ny][nx] != zone:
						#when we find to neighrbouring nodes that are not a big room
						#we add their edges because that could be candidates to a door.
						var a = Vector2i(cx, cy)
						var b = Vector2i(nx, ny)
						var key = [a, b]
						var reverse_key = [b, a]
						if not edge_set.has(key) and not edge_set.has(reverse_key):
							edge_set[key] = true
							edges.append([a, b])
					else:
						if not visited[ny][nx]:
							visited[ny][nx] = true
							region_map[ny][nx] = region
							queue.append([nx, ny])

			groups_edges.append(edges)
			region_cells.append(queue) #queue now holds every cell of this region.

	candidates.shuffle()
	var target_per_zone = int(HEIGHT * WIDTH / NB_ZONES)
	#number of rooms we want for each zone
	var region_zone = [] #which zone owns each region, -1 if unclaimed.
	for r in range(region_cells.size()):
		region_zone.append(-1)

	var seed_idx = 0
	for i in range(NB_ZONES):
		#starting point of our zones. Skip candidates whose region
		#was already claimed by an earlier zone seed.
		while seed_idx < candidates.size() and region_zone[region_map[candidates[seed_idx][1]][candidates[seed_idx][0]]] != -1:
			seed_idx += 1
		if seed_idx >= candidates.size():
			break
		var x = candidates[seed_idx][0]
		var y = candidates[seed_idx][1]
		region = region_map[y][x]
		seed_idx += 1

		region_zone[region] = i
		for cell in region_cells[region]:
			zone_map[cell[1]][cell[0]] = i
			zone_queues[i].append(cell)
		zone_sizes[i] = region_cells[region].size()
		if i == 0:
			zone_0 = [x, y]

	var active = true
	#we iterate trough each zone respecting each zone quota until there
	#are no more nodes without zone. Each node of a zone will try to add
	#all nodes in each of his cardinal directions.
	while active:
		active = false
		for z in range(NB_ZONES):
			var steps = min(zone_queues[z].size(), 20)  # cap per iteration batch

			for s in range(steps):
				var cell = zone_queues[z].pop_front()
				var x = cell[0]
				var y = cell[1]

				for dir in [[1,0], [-1,0], [0,1], [0,-1]]:
					var nx = x + dir[0]
					var ny = y + dir[1]
					if nx < 0 or nx >= WIDTH or ny < 0 or ny >= HEIGHT:
						continue
					if map[ny][nx] > 0 and zone_map[ny][nx] == -1:
						if zone_sizes[z] < target_per_zone:
							region = region_map[ny][nx]
							if region_zone[region] == -1:
								#claim the whole region at once, not just this cell.
								region_zone[region] = z
								for rcell in region_cells[region]:
									zone_map[rcell[1]][rcell[0]] = z
									zone_queues[z].append(rcell)
								zone_sizes[z] += region_cells[region].size()
								active = true
	return [candidates, groups_edges, zone_0]


func create_room(x, y, zone, size, T):
	# Draws the border of one map cell, side by side.
	var cell = Vector2i(x, y)
	for dir in SIDES:
		draw_side(cell, dir, zone, size, T)
		
func draw_side(cell: Vector2i, dir: Vector2i, zone: int, size: int, T) -> void:
	# Decides what goes on one side of the cell: a wall with a door,
	# a plain wall, or nothing (same big room).
	var neighbor = cell + dir
	if has_open_connection(T, cell, neighbor):
		draw_wall(cell, dir, zone, size, true)
	elif is_room_boundary(cell, neighbor, zone):
		draw_wall(cell, dir, zone, size, false)
	else:
		link_rooms(cell, neighbor)   # same big room, in bounds (out of bounds counts as boundary)

func is_room_boundary(cell: Vector2i, neighbor: Vector2i, zone: int) -> bool:
	# True if the neighbor is outside the map or is not part of the same big room.
	if neighbor.x < 0 or neighbor.x >= WIDTH or neighbor.y < 0 or neighbor.y >= HEIGHT:
		return true
	return map[neighbor.y][neighbor.x] != map[cell.y][cell.x] or zone_map[neighbor.y][neighbor.x] != zone
		
func draw_wall(cell: Vector2i, dir: Vector2i, zone: int, size: int, with_door: bool) -> void:
	# Draws the wall on the side of `cell` facing `dir`, and the obstacles
	# stacked against it, in a single pass over the tiles of that side.
	var wall_tile
	var start = cell * size + Vector2i(maxi(dir.x, 0), maxi(dir.y, 0)) * (size - 1)
	var step = Vector2i(absi(dir.y), absi(dir.x))
	var layers = rng.randi_range(MIN_LAYERS, MAX_LAYERS)  # obstacle layers for this side
	var left_depth = 0
	var right_depth = 0
	var door_first = size / 4
	var door_last = 3 * size / 4 - 1
	skip_streaks = []
	for i in range(MAX_LAYERS):
		skip_streaks.append(0)
	for i in range(size):
		var pos = start + step * i
		if with_door and is_door_index(i, size):
			#set_cell(0, pos, 0, DOOR_TILE)  # doorway: no obstacles here
			continue
		wall_tile = Vector2i(rng.randi_range(0, 7), 2) #reemplazar por zone si quiero zona
		set_cell(0, pos, 0, wall_tile)
		var depth = add_obstacle_column(pos, dir, i, size, layers, wall_tile)
		if i == door_first - 1:
			left_depth = depth
		elif i == door_last + 1:
			right_depth = depth
	if with_door:
		var door_depth = 0
		if dir.y != 0:   # only top/bottom walls
			door_depth = mini(left_depth, right_depth)
		for i in range(door_first, door_last + 1):
			set_cell(0, start + step * i - dir * door_depth, 0, DOOR_TILE)
			
func add_obstacle_column(wall_pos: Vector2i, dir: Vector2i, i: int, size: int, layers: int, tile: Vector2i):
	# Stacks obstacles against the wall tile at `wall_pos`, going inward.
	# Layer k only exists in columns k to size - k - 1, so column i takes
	# part in min(layers, i, size - 1 - i) layers.
	var min_depth = size / 4 - 1 #the minimum so that there isn't walls next to doors
	var max_depth = mini(layers, maxi(mini(i, size - 1 - i), min_depth))
	var depth = 0
	for n in range(max_depth):
		if rng.randf() < get_skip_chance(n, i, size):
			skip_streaks[n] += 1
			continue
		depth += 1
		var pos = wall_pos - dir * depth
		tile = Vector2i(rng.randi_range(0, 7), 2) #cambiar si estamos seteando por zona
		set_cell(0, pos, 0, tile)
		skip_streaks[n] = 0
		obstacles[pos] = true
	return depth

func get_skip_chance(n, i, size) -> float:
	if i <= 1 or i >= size - 2:
		return 0.0
	elif skip_streaks[n] == 0:
		return SKIP_CHANCE
	elif skip_streaks[n] <= 3:
		return SKIP_CHANCE_ONE_EMPTY
	return SKIP_CHANCE_MANY_EMPTY

func is_door_index(i: int, size: int) -> bool:
	# The door is the middle half of the wall.
	return i >= size / 4 and i < 3 * size / 4
	

func choose_border(map):
	#finds a random node in the border of the map, then returns it.
	var candidates = []
	for y in range(HEIGHT):
		for x in range(WIDTH):
			if map[y][x] == 0:
				continue
			# check if it's a border tile
			var is_border = false
			if y > 0 and map[y - 1][x] == 0 and not is_sourounded(map, x, y - 1):
				is_border = true
			elif y < HEIGHT - 1 and map[y + 1][x] == 0 and not is_sourounded(map, x, y + 1):
				is_border = true
			elif x > 0 and map[y][x - 1] == 0 and not is_sourounded(map, x - 1, y):
				is_border = true
			elif x < WIDTH - 1 and map[y][x + 1] == 0 and not is_sourounded(map, x + 1, y):
				is_border = true
			if is_border:
				candidates.append([x, y])
	if candidates.is_empty():
		return [WIDTH / 2, HEIGHT / 2] # fallback
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func print_map(map):
	#prints the map in the console. Purelly for testing purpuses.
	for i in map:
		print(i)
		print("\n")

func is_sourounded(map, x, y):
	#tells if a room is sourrounded by other rooms.
	#Usefull for chose_border function because it helps to find
	#nodes that are not rooms but next to rooms, and that are not a border.
	if y - 1 < 0 or map[y - 1][x] == 0:
		return false
	if y + 1 >= HEIGHT or map[y + 1][x] == 0:
		return false
	if x - 1 < 0 or map[y][x - 1] == 0:
		return false
	if x + 1 >= WIDTH or map[y][x + 1] == 0:
		return false
	return true 

func randomized_kruskal(map, group_edges):
	#sets the doors between rooms. Ensures that there is only one path
	#to get to each room. Returns a set with all the doors.
	var T = {} #the set that stores the edge as a key, the value is always true.
	var region_edges = {} #helps to know if two rooms are already connected
	#(this can happen with big rooms).
	var all_edges = []
	#all edges will get all the edges without region repeat.
	for group in group_edges:
		for e in group:
			var a = e[0]
			var b = e[1]
			var ra = region_map[a.y][a.x]
			var rb = region_map[b.y][b.x]
			if ra == -1 or rb == -1:
				continue
			if ra == rb:
				continue
			var key = str(min(ra, rb)) + "_" + str(max(ra, rb))
			if not region_edges.has(key):
				region_edges[key] = [a, b]
				all_edges.append([a, b])
	all_edges.shuffle()

	#standart randomized kruskal
	var parent = {}
	var rank = {}
	for e in all_edges:
		var a = e[0]
		var b = e[1]
		var ra = region_map[a.y][a.x]
		var rb = region_map[b.y][b.x]
		if not parent.has(ra):
			parent[ra] = ra
			rank[ra] = 0
		if not parent.has(rb):
			parent[rb] = rb
			rank[rb] = 0

	for e in all_edges:
		var a = e[0]
		var b = e[1]
		var ra = region_map[a.y][a.x]
		var rb = region_map[b.y][b.x]
		if union(parent, rank, ra, rb):   # <-- union on region ids, not tile coords
			T[[a, b]] = true
	return T
	
func find(parent, x):
		#returns the parent of x.
		if parent[x] != x:
			parent[x] = find(parent, parent[x])
		return parent[x]

func union(parent, rank, a, b):
	#returns true if you can get from a to b.
	var ra = find(parent, a)
	var rb = find(parent, b)
	if ra == rb:
		return false

	if rank[ra] < rank[rb]:
		parent[ra] = rb
	elif rank[ra] > rank[rb]:
		parent[rb] = ra
	else:
		parent[rb] = ra
		rank[ra] += 1

	return true

func compute_region_bounds() -> void:
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var r = region_map[y][x]
			if r == -1:
				continue
			var cell_rect = Rect2i(x, y, 1, 1)
			if region_bounds.has(r):
				region_bounds[r] = region_bounds[r].merge(cell_rect)
			else:
				region_bounds[r] = cell_rect

func has_open_connection(T, a: Vector2i, b: Vector2i) -> bool:
	#returns true of there is a door beyween a or b.
	return T.has([a, b]) or T.has([b, a])

func same_region(a: Vector2i, b: Vector2i) -> bool:
	#returns true if a or b are from the same region (big room).
	if b.x < 0 or b.y < 0 or b.x >= WIDTH or b.y >= HEIGHT:
		return false
	return region_map[a.y][a.x] == region_map[b.y][b.x]
	
func register_room(cell: Vector2i) -> void:
	if not big_rooms.has(cell):
		big_rooms[cell] = [cell]
		
func link_rooms(a: Vector2i, b: Vector2i) -> void:
	register_room(a)
	register_room(b)
	var group_a = big_rooms[a]
	var group_b = big_rooms[b]
	if group_a.has(b):   # already known to be together (every pair is visited twice)
		return
	# merge b's group into a's, and repoint every member of b to the merged array
	for room in group_b:
		group_a.append(room)
		big_rooms[room] = group_a
