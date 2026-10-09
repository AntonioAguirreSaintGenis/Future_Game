extends Node2D

@export var door1: StaticBody2D = null
@export var door2: StaticBody2D = null
@export var door3: StaticBody2D = null
@export var door4: StaticBody2D = null
@onready var doors = [door1, door2, door3, door4]
@onready var boss = $Boss


# Called when the node enters the scene tree for the first time.
func _ready():
	boss.asign_room(self)

func end_boss():
	for i in doors:
		if i != null:
			i.end_boss()

func _on_detection_bosses_body_entered(body):
	print(1)
	if body == boss.target and boss.agro == false:
		boss.agro = true # Replace with function body.
		boss.barr.start_battle()
		for i in doors:
			if i != null:
				i.start_boss()
