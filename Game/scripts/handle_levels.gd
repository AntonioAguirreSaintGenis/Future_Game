extends Node2D 

@onready var _dimensions: Vector2i = Vector2i(7, 5)

var dungeon: Array

var lLayouts = []
var lEnemies = []
var lTraps = []

func _ready() -> void:
	_initialize_dungeon()
	_print_dungeon()
	
	
func _initialize_dungeon():
	#sumas las columnas (que son listas, y las llenas con las filas (y) que tienen valor 0 porque no hay nada.
	for x in _dimensions.x:
		dungeon.append([])
		for y in _dimensions.y:
			dungeon[x].append(0)


func _print_dungeon():
	var dungeon_as_string = ""
	for y in range(_dimensions.y -1, -1, -1):
		for x in _dimensions.x:
			dungeon_as_string += "[" + str(dungeon[x][y]) + "]"
		dungeon_as_string += "\n"
	print(dungeon_as_string)
