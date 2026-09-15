extends Control

@onready var health_bar = $Healthbar

var player

func _ready():
	player = get_tree().current_scene.get_node("Player")
	health_bar.max_value = player.health
	health_bar.value = player.health

func _process(delta):
	health_bar.value = player.health
