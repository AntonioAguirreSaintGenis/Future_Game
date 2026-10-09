extends StaticBody2D

@onready var sprite2D = $Sprite2D
@onready var collision = $CollisionShape2D

func _ready():
	end_boss()

func end_boss():
	sprite2D.visible = false
	collision.set_deferred("disabled", true)

func start_boss():
	sprite2D.visible = true
	collision.set_deferred("disabled", false)
