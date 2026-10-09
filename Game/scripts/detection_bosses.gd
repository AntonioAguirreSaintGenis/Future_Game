extends Area2D

@export var boss: CharacterBody2D

func start_boss(body, boss):
	if body == boss.target and boss.agro == false:
		boss.agro = true # Replace with function body.
		boss.barr.start_battle()

func asign_boss(b):
	boss = b
