extends TileMap

@onready var player = $Player
@onready var camera = $Player/Camera2D

const DOOR_TILE = Vector2i(0, 1)
const SIDES = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const MAX_LAYERS = 5      # a side gets between MIN_LAYERS and MAX_LAYERS layers
const MIN_LAYERS = 2

const GEN_BUDGET_USEC = 3000   # max time spent generating per frame
const UNLOAD_RADIUS = 2        # rooms further than this (in cells) from the player get erased

const SKIP_CHANCE = 0.05#0.035
const SKIP_CHANCE_ONE_EMPTY = 0.95
const SKIP_CHANCE_MANY_EMPTY =  0.25

const CAM_SPEED_NORMAL = 25.0      # follow speed inside a room
const CAM_SPEED_TRANSITION = 5.0   # glide speed after changing region
const CAM_TRANSITION_TIME = 0.7

const ROOM_DOOR_VERTICAL = "res://scenes/levels/cloud_door_vertical.tscn"
const ROOM_DOOR_HORIZONTAL = "res://scenes/levels/cloud_door_horizontal.tscn"

const MAX_DIFFICULTY = 6

const DOOR_SPAWN_MARGIN = 1   # tiles the player must be inside the room before its doors close
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
var created = {}
var cleared = {}
var current_doors = []
var pending: Array[Vector2i] = []   # terrain cells collected while one room is built
var gen_queue = []                  # rooms waiting to be generated, current room first
var unload_queue = []               # far rooms waiting to be erased
var world_seed = 0
var enemies_generated = {}
var enemies_id = 0
var enemies_list = ["res://scenes/ennemies/enemy1.tscn", "res://scenes/ennemies/enemy_2.tscn", "res://scenes/ennemies/enemy_3.tscn"]
var doors_pending = false
var enemies_pending = false
var door_cell = Vector2i(-1, -1)

func _ready():
	rng.randomize()
	world_seed = rng.randi()
	skip_streaks.resize(MAX_LAYERS)
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
	var forced_start = force_single_room_start()
	var candidates = flood_fill_zones(map, visited, forced_start)
	compute_region_bounds()
	var group_edges = candidates[1]
	player.position = map_to_local(Vector2(candidates[2][0] * room_size + MAX_LAYERS, candidates[2][1] * room_size + MAX_LAYERS))
	var start_cell = Vector2i(candidates[2][0], candidates[2][1])
	var region_id = region_map[start_cell.y][start_cell.x]
	for room in big_rooms[region_id]:
		cleared[room] = true
	candidates = candidates[0]
	doors = randomized_kruskal(map, group_edges)
	#var edges = zone_edges()
	#apply_zones_to_tiles(candidates, doors)
	
	#draw empty tiles
	"""for y in range(HEIGHT):
		for x in range(WIDTH):
			if map[y][x] == 0:
				for ty in range(room_size):
					for tx in range(room_size):
						set_cell(0,Vector2i(x * room_size + tx, y * room_size + ty),0,Vector2i(1, 1))
	#set_cell(0, Vector2i(0, 0), 0, Vector2i(7, 0))"""
	#print_map(map)

func _process(_delta):
	var start = Time.get_ticks_usec()
	while not gen_queue.is_empty():
		draw_room_group(gen_queue.pop_front(), doors)
		if Time.get_ticks_usec() - start > GEN_BUDGET_USEC:
			break
	# erase at most one far room per frame, and only when nothing is waiting to be built
	if gen_queue.is_empty() and not unload_queue.is_empty():
		var room = unload_queue.pop_front()
		for en in enemies_generated.get(room, {}).values():
			if is_instance_valid(en):
				en.queue_free()
		enemies_generated.erase(room)
		for ty in range(room_size):
			for tx in range(room_size):
				erase_cell(0, Vector2i(room.x * room_size + tx, room.y * room_size + ty))
		created.erase(room)
		
func _physics_process(_delta):
	var cell = get_room_of(player.global_position)
	if cell.x < 0 or cell.y < 0 or cell.x >= WIDTH or cell.y >= HEIGHT:
		return
	if cell != current_room:
		current_room = cell
		var region = region_map[cell.y][cell.x]
		if region != current_region and region_bounds.has(region):
			current_region = region
			update_camera_limits(region_bounds[region])
			for door in current_doors:
				if is_instance_valid(door):
					door.queue_free()
			current_doors.clear()
			door_cell = cell
			doors_pending = true
		update_rooms(cell.x, cell.y, zone_map[cell.y][cell.x])
		enemies_pending = true
	if enemies_pending and created.has(cell) and is_inside_room(door_cell):
		enemies_pending = false
		generate_enemies(cell.x, cell.y)
	#if no enemmies left open the room
	if not cleared.has(cell) and enemies_generated.has(cell) and enemies_generated[cell].is_empty():
		var region_id = region_map[cell.y][cell.x]
		for room in big_rooms[region_id]:
			cleared[room] = true
		for door in current_doors:
			if is_instance_valid(door):
				door.queue_free()
		current_doors.clear()
		update_current_doors(cell)
	#close the doors behind the player
	if doors_pending and is_inside_room(door_cell):
		doors_pending = false
		update_current_doors(door_cell)

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
				
func flood_fill_zones(map, visited_original, start_cell):
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
			var edges = []
			var queue: Array[Vector2i] = []
			queue.append(Vector2i(x, y))
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
				var cx = cell.x
				var cy = cell.y
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
							queue.append(Vector2i(nx, ny))

			groups_edges.append(edges)
			region_cells.append(queue) #queue now holds every cell of this region.
			big_rooms[next_region - 1] = queue
	
	#candidates.erase([start_cell.x, start_cell.y])
	candidates.shuffle()
	var target_per_zone = int(HEIGHT * WIDTH / NB_ZONES)
	#number of rooms we want for each zone
	var region_zone = [] #which zone owns each region, -1 if unclaimed.
	for r in range(region_cells.size()):
		region_zone.append(-1)
	zone_0 = [start_cell.x, start_cell.y]
	region = region_map[start_cell.y][start_cell.x]
	region_zone[region] = 0
	for cell in region_cells[region]:
		zone_map[cell.y][cell.x] = 0
		zone_queues[0].append(cell)
	zone_sizes[0] = region_cells[region].size()
	
	var seed_idx = 0
	for i in range(1, NB_ZONES):
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
			zone_map[cell.y][cell.x] = i
			zone_queues[i].append(cell)
		zone_sizes[i] = region_cells[region].size()

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
				var x = cell.x
				var y = cell.y

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
									zone_map[rcell.y][rcell.x] = z
									zone_queues[z].append(rcell)
								zone_sizes[z] += region_cells[region].size()
								active = true
	return [candidates, groups_edges, zone_0]


func create_room(x, y, zone, size, T):
	# Draws the border of one map cell, side by side.
	rng.seed = hash([world_seed, x, y])   # a room looks the same every time it is regenerated
	obstacles.clear()  
	var cell = Vector2i(x, y)
	for dir in SIDES:
		draw_side(cell, dir, zone, size, T)

	var draw_obstacles = rng.randi_range(0, 3)
	var above = cell + Vector2i(0, -1)
	var below = cell + Vector2i(0, 1)
	var left = cell + Vector2i(-1, 0)
	var right = cell + Vector2i(1, 0)
	var connection_above = has_open_connection(T, cell, above)
	var connection_below = has_open_connection(T, cell, below)
	var connection_left = has_open_connection(T, cell, left)
	var connection_right = has_open_connection(T, cell, right)
	if draw_obstacles > 0:
		#we create obstacles only from up or down but not both so that we do not block completely the way.
		if draw_obstacles == 1:
			draw_one_of_kind_obstacle(cell, connection_above, connection_below, above, below, connection_left, connection_right, left, right, x, y)
		#here are the obstacles that can't block the way no matter what
		elif draw_obstacles == 2:
			draw_multiple_of_kind_obstacle(x, y)
		else:
			var one_of_kind = bool(rng.randi() % 2)
			if one_of_kind:
				draw_one_of_kind_obstacle(cell, connection_above, connection_below, above, below, connection_left, connection_right, left, right, x, y)
				for i in range(1, rng.randi_range(draw_obstacles, draw_obstacles + 2)):
					draw_multiple_of_kind_obstacle(x, y)
			else:
				for i in range(rng.randi_range(draw_obstacles, draw_obstacles + 2)):
					draw_multiple_of_kind_obstacle(x, y)
		#one_way_platform_symetrical_low(x, y, 0.25)
	set_cells_terrain_connect(0, pending, 0, 0)   # one terrain solve for the whole room
	pending.clear()
	
func draw_side(cell: Vector2i, dir: Vector2i, zone: int, size: int, T) -> void:
	# Decides what goes on one side of the cell: a wall with a door,
	# a plain wall, or nothing (same big room).
	var neighbor = cell + dir
	if has_open_connection(T, cell, neighbor):
		draw_wall(cell, dir, zone, size, true)
	elif is_room_boundary(cell, neighbor, zone):
		draw_wall(cell, dir, zone, size, false)
	"""else:
		link_rooms(cell, neighbor)   # same big room, in bounds (out of bounds counts as boundary)"""

func is_room_boundary(cell: Vector2i, neighbor: Vector2i, zone: int) -> bool:
	# True if the neighbor is outside the map or is not part of the same big room.
	if neighbor.x < 0 or neighbor.x >= WIDTH or neighbor.y < 0 or neighbor.y >= HEIGHT:
		return true
	return map[neighbor.y][neighbor.x] != map[cell.y][cell.x] or zone_map[neighbor.y][neighbor.x] != zone

func is_inside_room(cell: Vector2i) -> bool:
	var tile = local_to_map(to_local(player.global_position))
	var lx = tile.x - cell.x * room_size
	var ly = tile.y - cell.y * room_size
	return lx >= DOOR_SPAWN_MARGIN and lx < room_size - DOOR_SPAWN_MARGIN \
		and ly >= DOOR_SPAWN_MARGIN and ly < room_size - DOOR_SPAWN_MARGIN
	
func draw_wall(cell: Vector2i, dir: Vector2i, zone: int, size: int, with_door: bool) -> void:
	var start = cell * size + Vector2i(maxi(dir.x, 0), maxi(dir.y, 0)) * (size - 1)
	var step = Vector2i(absi(dir.y), absi(dir.x))
	var layers = rng.randi_range(MIN_LAYERS, MAX_LAYERS)
	skip_streaks.fill(0)
	for i in range(size):
		var pos = start + step * i
		# Leave the doorway empty.
		if with_door and is_door_index(i, size):
			continue
		pending.append(pos)
		add_obstacle_column(pos, dir, i, size, layers)
			
func add_obstacle_column(wall_pos: Vector2i, dir: Vector2i, i: int, size: int, layers: int):
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
		#tile = Vector2i(rng.randi_range(0, 7), 2) #cambiar si estamos seteando por zona
		#set_cell(0, pos, 0, tile)
		pending.append(pos)
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
	
"""func register_room(cell: Vector2i) -> void: #to delete
	if not big_rooms.has(cell):
		big_rooms[cell] = [cell]"""
		
"""func link_rooms(a: Vector2i, b: Vector2i) -> void: #to delete
	register_room(a)
	register_room(b)
	var group_a = big_rooms[a]
	var group_b = big_rooms[b]
	if group_a.has(b):   # already known to be together (every pair is visited twice)
		return
	# merge b's group into a's, and repoint every member of b to the merged array
	for room in group_b:
		group_a.append(room)
		big_rooms[room] = group_a"""
		
#terrain obscacles generation functions
func pillar(room_x, room_y, from_ceiling, probability):
	var chance_vertical
	var chance_horizontal
	var max_height = room_size - 1 - MAX_LAYERS - 3
	var x = rng.randi_range(MAX_LAYERS + 1, room_size - max_height)
	# from_ceiling: the pillar hangs down (0, 1). Otherwise it grows up from the floor (0, -1).
	var grow = Vector2i(0, 1) if from_ceiling else Vector2i(0, -1)
	var base = Vector2i(room_x * room_size + x, room_y * room_size)
	if not from_ceiling:
		base.y += room_size - 1   # wall row
	# keeps 2 free blocks between the pillar's tip and the opposite wall's layers,
	# assuming the pillar starts right at the wall. Reduced below by the offset.
	for i in range(rng.randi_range(2, 5)):   # horizontal: max width of 3 columns
		chance_horizontal = 1.0 if i < 2 else 1.0 - 0.5
		if rng.randf() > chance_horizontal:
			break
		# first row inside the wall, then skip past the obstacle stack of this column
		var start = base + Vector2i(i, 0) + grow
		var offset = 0
		while offset < room_size and obstacles.has(start + grow * offset):
			offset += 1
		start += grow * offset
		# the taller the stack under the pillar, the less room is left above it
		var height = mini(rng.randi_range(4, 8), max_height - offset)
		for j in range(height):
			chance_vertical = 1.0 if j <= height * 0.5 else 1.0 - probability
			var pos = start + grow * j
			if rng.randf() > chance_vertical or obstacles.has(pos):
				break
			pending.append(pos)
			obstacles[pos] = true

func pillar_horizontal(room_x, room_y, from_left, probability):
	var chance_vertical
	var chance_horizontal
	var max_width = room_size - 1 - MAX_LAYERS - 3
	var y = rng.randi_range(MAX_LAYERS + 1, room_size - max_width)
	# from_left: pillar grows right (1, 0). Otherwise it grows left (-1, 0).
	var grow = Vector2i(1, 0) if from_left else Vector2i(-1, 0)
	var base = Vector2i(room_x * room_size, room_y * room_size + y)
	if not from_left:
		base.x += room_size - 1
	for i in range(rng.randi_range(2, 5)):
		chance_horizontal = 1.0 if i < 2 else 1.0 - 0.5
		if rng.randf() > chance_horizontal:
			break
		# First column inside the wall, then skip past existing obstacles.
		var start = base + Vector2i(0, i) + grow
		var offset = 0
		while offset < room_size and obstacles.has(start + grow * offset):
			offset += 1
		start += grow * offset
		# The wider the existing obstacle stack, the less room remains.
		var width = mini(rng.randi_range(4, 8), max_width - offset)
		for j in range(width):
			chance_vertical = 1.0 if j <= width * 0.5 else 1.0 - probability
			var pos = start + grow * j
			if rng.randf() > chance_vertical or obstacles.has(pos):
				break
			pending.append(pos)
			obstacles[pos] = true

func one_way_platform(room_x, room_y, local_x, local_y, probability):
	var chance = 1.0
	var max_height = room_size - 1 - MAX_LAYERS - 3
	var x = room_x * room_size + local_x
	var y = room_y * room_size + local_y
	var grow
	if local_x > room_size/2:
		grow = -1
	else:
		grow = 1
	for i in range(room_size - max_height):
		if i > 2:
			chance = 1.0 - probability
		var pos = Vector2i(x, y)
		if rng.randf() > chance or obstacles.has(pos):
			break
		set_cell(0, pos, 0, Vector2i(2, 1))
		obstacles[pos] = true
		x += grow
		
func one_way_platform_low(room_x, room_y, probability):
	var max_height = room_size - 1 - MAX_LAYERS - 3
	var local_x = random_platform_x()
	var local_y = rng.randi_range(MAX_LAYERS + 2, room_size - 3 - MAX_LAYERS)
	if rng.randf() < 0.5:   # extra chance to land in the 50%-35% height band
		local_y = rng.randi_range(roundi(lerpf(max_height, room_size - 1 - max_height, 0.35)), roundi(lerpf(max_height, room_size - 1 - max_height, 0.5)))
	one_way_platform(room_x, room_y, local_x, local_y, probability)

func one_way_platform_high(room_x, room_y, probability):
	var max_height = room_size - 1 - MAX_LAYERS - 3
	var local_x = random_platform_x()
	var local_y = rng.randi_range(MAX_LAYERS + 2, room_size - 3 - MAX_LAYERS)
	if rng.randf() < 0.5:   # extra chance to land in the 50%-35% height band
		local_y = rng.randi_range(room_size - 1 - max_height, roundi(lerpf(max_height, room_size - 1 - max_height, 0.65)))
	one_way_platform(room_x, room_y, local_x, local_y, probability)
	
func one_way_platform_symetrical_low(room_x, room_y, probability):
	var max_height = room_size - 1 - MAX_LAYERS - 3
	var local_y = rng.randi_range(MAX_LAYERS + 2, room_size - 3 - MAX_LAYERS)
	var offset = 0.4
	if rng.randf() < 0.5:   # extra chance to land in the 50%-35% height band
		local_y = rng.randi_range(roundi(lerpf(max_height, room_size - 1 - max_height, 0.35)), roundi(lerpf(max_height, room_size - 1 - max_height, 0.5)))
	# Left platform: starts between the left wall and 35%
	var left_x = rng.randi_range(
		MAX_LAYERS + 1,
		roundi(room_size * 0.35)
	)
	# Right platform: starts between the center and 65%
	var right_x = rng.randi_range(
		roundi(room_size * 0.85),
		room_size - 2 - MAX_LAYERS
	)
	one_way_platform(room_x, room_y, left_x, local_y, probability + offset)
	one_way_platform(room_x, room_y, right_x, local_y, probability + offset)

func one_way_platform_symetrical_high(room_x, room_y, probability):
	var max_height = room_size - 1 - MAX_LAYERS - 3
	var local_y = rng.randi_range(MAX_LAYERS + 2, room_size - 3 - MAX_LAYERS)
	var offset = 0.4
	if rng.randf() < 0.5:   # extra chance to land in the 50%-35% height band
		local_y = rng.randi_range(room_size - 1 - max_height, roundi(lerpf(max_height, room_size - 1 - max_height, 0.65)))
	var left_x = rng.randi_range(
		MAX_LAYERS + 1,
		roundi(room_size * 0.35)
	)
	# Right platform: starts between the center and 65%
	var right_x = rng.randi_range(
		roundi(room_size * 0.85),
		room_size - 2 - MAX_LAYERS
	)
	one_way_platform(room_x, room_y, left_x, local_y, probability + offset)
	one_way_platform(room_x, room_y, right_x, local_y, probability + offset)

func one_way_platform_symetrical_vertical(room_x, room_y, probability):
	var max_height = room_size - 1 - MAX_LAYERS - 3
	# lower platform: always below 50% height
	var half_y = roundi(lerpf(max_height, room_size - 1 - max_height, 0.5))
	var lower_y = rng.randi_range(half_y, max_height)
	# upper platform: 2 or 3 levels higher (smaller y), same x
	var upper_y = maxi(lower_y - rng.randi_range(2, 3), MAX_LAYERS + 2)
	var local_x = random_platform_x()
	one_way_platform(room_x, room_y, local_x, lower_y, probability)
	one_way_platform(room_x, room_y, local_x, upper_y, probability)

func floating_island(room_x, room_y, probability):
	var max_height = room_size - 1 - MAX_LAYERS - 3
	var local_y = rng.randi_range(MAX_LAYERS + 2, max_height - 2)
	var min_local_x = MAX_LAYERS + 2
	var max_local_x = room_size - 1 - MAX_LAYERS - 2
	var middle_x = floori(room_size * 0.5)
	var local_x
	if rng.randf() < 0.5:
		local_x = rng.randi_range(min_local_x, mini(middle_x, max_local_x - 4))
	else:
		local_x = rng.randi_range(maxi(middle_x + 1, min_local_x + 4), max_local_x)
	var y
	var x = room_x * room_size + local_x
	var grow
	var chance
	var not_drawn
	if local_x > room_size/2:
		grow = -1
	else:
		grow = 1
	var lim_x = room_size - 1 - MAX_LAYERS - 2 - local_x if grow == 1 else local_x - MAX_LAYERS - 2
	var center = floori(float(lim_x) / 2.0)
	var base_y = room_y * room_size + local_y
	#first pos
	"""if not obstacles.has(Vector2i(x, base_y)):
		set_cell(0, Vector2i(x, base_y), 0, Vector2i(rng.randi_range(0, 7), 2))
		obstacles[Vector2i(x, base_y)] = true
	#las pos
	if not obstacles.has(Vector2i(x + grow * lim_x, base_y)):
		set_cell(0, Vector2i(x + grow * lim_x, base_y), 0, Vector2i(rng.randi_range(0, 7), 2))
		obstacles[Vector2i(x + grow * lim_x, base_y)] = true
	x += grow"""
	for i in range(0, lim_x + 1):
		y = room_y * room_size + local_y
		not_drawn = 0
		var distance = absi(i - center)
		for j in range(max_height - local_y + 1):
			# chance to keep the tile: drops with distance from the middle column and with each row below the 2nd
			if distance == 0 and j < 3:
				chance = 1.0
			elif distance <= 1 and j < 2:
				chance = 1.0
			else:
				chance = 1.0 - probability - 0.1 * distance - 0.1 * maxi(j - 1, 0)
				if not_drawn >= 2:
					chance += chance * 0.5
					not_drawn = 0
			var pos = Vector2i(x, y)
			if obstacles.has(pos):
				break
			if j == 0 and i < mini(2, lim_x): #i want at least 4 blocks, so 2 + the 2 already drawn before the loops.
				chance = 1.0
			if rng.randf() > chance and j != 0:
				not_drawn += 1
				continue
			pending.append(pos)
			obstacles[pos] = true
			y += 1
		x += grow
	
func random_platform_x() -> int:
	if rng.randf() < 0.5:
		return rng.randi_range(MAX_LAYERS + 1, roundi(room_size * 0.4))
	return rng.randi_range(roundi(room_size * 0.60), room_size - 2 - MAX_LAYERS)

func draw_one_of_kind_obstacle(cell, connection_above, connection_below, above, below, connection_left, connection_right, left, right, x, y):
	var choose = rng.randi_range(0, 4)
	if choose == 0 and not connection_above and not same_region(cell, above):
		pillar(x, y, true, 0.25)
	elif choose == 1 and not connection_below and not same_region(cell, below):
		pillar(x, y, false, 0.25)
	elif choose == 2 and not connection_left and not same_region(cell, left):
		pillar_horizontal(x, y, true, 0.25)
	elif choose == 3 and not connection_right and not same_region(cell, right):
		pillar_horizontal(x, y, false, 0.25)
	else:
		floating_island(x, y, 0.3)

func draw_multiple_of_kind_obstacle(x, y):
	var other_obstacles = [
		one_way_platform_symetrical_vertical, 
		one_way_platform_symetrical_low,
		one_way_platform_low,
		one_way_platform_symetrical_high,
		one_way_platform_high
	]
	var chosen = rng.randi_range(0, len(other_obstacles) - 1)
	if chosen > 2:
		chosen = rng.randi_range(0, len(other_obstacles) - 2)
	other_obstacles[chosen].call(x, y, 0.25)

func full_room(x, y):
	# Creates an empty room (a room that isn't a room in map).
	var start = Vector2i(x * room_size, y * room_size)
	for ty in range(room_size):
		for tx in range(room_size):
			set_cell(0, start + Vector2i(tx, ty), 0, Vector2i(rng.randi_range(0, 2), 14))
	
func update_rooms(x, y, zone):
	var cell = Vector2i(x, y)
	gen_queue.clear()          # drop stale entries from rooms we already left
	gen_queue.append(cell)     # current room always first
	for dir in SIDES:
		var neighbor = cell + dir
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= WIDTH or neighbor.y >= HEIGHT:
			continue
		gen_queue.append(neighbor)
	unload_queue.clear()
	for room in created.keys():
		if maxi(absi(room.x - x), absi(room.y - y)) > UNLOAD_RADIUS:
			unload_queue.append(room)
		
func draw_room_group(cell: Vector2i, T) -> void:
	if created.has(cell):
		return
	if map[cell.y][cell.x] > 0:
		create_room(cell.x, cell.y, zone_map[cell.y][cell.x], room_size, T)
	else:
		full_room(cell.x, cell.y)
	created[cell] = true

func update_current_doors(cell: Vector2i) -> void:
	# Don't create doors if this room has already been cleared.
	if cleared.has(cell):
		return
	var region_id = region_map[cell.y][cell.x]
	if region_id == -1 or not big_rooms.has(region_id):
		return
	var rooms = big_rooms[region_id]
	var tile_size_px = Vector2(tile_set.tile_size)
	var door_first = room_size / 4
	for room in rooms:
		for dir in SIDES:
			var neighbor = room + dir
			if not has_open_connection(doors, room, neighbor):
				continue
			# Choose the correct door scene based on wall orientation.
			var door: StaticBody2D
			if dir.y != 0:
				door = load(ROOM_DOOR_HORIZONTAL).instantiate() as StaticBody2D
			else:
				door = load(ROOM_DOOR_VERTICAL).instantiate() as StaticBody2D
			# Calculate the position of the doorway.
			var start = room * room_size + Vector2i(maxi(dir.x, 0), maxi(dir.y, 0)) * (room_size - 1)
			var step = Vector2i(absi(dir.y), absi(dir.x))
			add_child(door)
			door.position = map_to_local(start + step * door_first) \
				+ Vector2(step) * tile_size_px * 4.5
			current_doors.append(door)

func generate_enemies(x, y):
	var pos = Vector2i(x, y)
	if cleared.has(pos):
		return   # don't respawn enemies in a room that was already cleared
	if not enemies_generated.get(pos, {}).is_empty():
		return   # enemies still alive here, don't touch anything
	rng.seed = hash([world_seed, x, y])
	var tries = 10
	var actual_difficulty = 0
	var difficulty = rng.randi_range(MAX_DIFFICULTY/2, MAX_DIFFICULTY)
	enemies_generated[pos] = {}
	for i in range(tries):
		var en = load(enemies_list[rng.randi_range(0, len(enemies_list) - 1)])
		en = en.instantiate()
		if actual_difficulty + en.difficulty <= difficulty:
			enemies_generated[pos][enemies_id] = en
			add_child(en)
			en.set_pos(x, y, room_size, MAX_LAYERS, enemies_id)
			en.generate()
			actual_difficulty += en.difficulty
			enemies_id += 1
		else:
			en.queue_free()

func delete_enemy(pos, id):
	if enemies_generated.has(pos):
		enemies_generated[pos].erase(id)

func force_single_room_start() -> Vector2i:
	# Pick a random room and give it a value no other cell has, so the flood
	# fill can never merge it with its neighbours into a big room.
	var rooms: Array[Vector2i] = []
	var highest = 0
	for y in range(HEIGHT):
		for x in range(WIDTH):
			if map[y][x] > 0:
				rooms.append(Vector2i(x, y))
				highest = maxi(highest, map[y][x])
	var start = rooms[rng.randi_range(0, rooms.size() - 1)]
	map[start.y][start.x] = highest + 1
	return start
