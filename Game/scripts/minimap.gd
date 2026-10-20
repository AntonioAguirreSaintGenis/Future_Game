extends Control

const SIDES = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

var size_rect = 5
var world
var current_room = Vector2i(-1, -1)
var visited = {}   # room cell -> true
var offset = size_rect/2.0

func _ready():
	world = get_tree().current_scene

func _process(_delta):
	var room = world.get_room_of(world.player.global_position)
	if room != current_room:
		current_room = room
		queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	add_around(size / 2.0, size_rect)
	draw_circle(size/2.0, 1.5, Color.BLACK)
	#var marker =  Vector2(2, 2)
	#draw_rect(Rect2(size/2.0 - marker/2.0, marker), Color.YELLOW)

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < world.WIDTH and c.y < world.HEIGHT

func add_square(color, x, y, size_rect):
	var rect = Rect2(x, y, size_rect, size_rect)
	if not Rect2(Vector2.ZERO, size).encloses(rect):
		return
	draw_rect(rect, color, true, 1.0)

func add_around(center: Vector2, size_rect: int):
	if not in_bounds(current_room) or world.map[current_room.y][current_room.x] == 0:
		return
	var step = size_rect + 1
	# every cell of the big room the player is in (or just this cell if it's a normal room)
	var group
	if world.big_rooms.has(current_room):
		group = world.big_rooms[current_room]
	else:
		group = [current_room]
	for cell in group:
		visited[cell] = true
	# blue: rooms touching ANY cell of the group, excluding the group itself
	for cell in group:
		for d in SIDES:
			var n = cell + d
			if in_bounds(n) and world.map[n.y][n.x] > 0 and not group.has(n) and world.has_open_connection(world.doors, cell, n):
				var o = Vector2(n - current_room) * step
				if visited.has(n):
					add_square(Color.ORANGE, center.x + o.x - offset, center.y + o.y - offset, size_rect)
				else:
					add_square(Color.BLUE, center.x + o.x - offset, center.y + o.y - offset, size_rect)
	# red: the whole big room, positioned relative to the current cell
	for cell in group:
		var o = Vector2(cell - current_room) * step
		add_square(Color.RED, center.x + o.x - offset, center.y + o.y - offset, size_rect)
