extends Area2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var timer = $Timer
var spell_cast = false
var damage = 1
var offset = 50
var cost = 3


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if spell_cast:
		hitbox.hit(damage)

func start_spell(player):
	spell_cast = true
	if not player.animated_sprite.flip_h:
		animated_sprite.flip_h = false
		animated_sprite.offset.x = offset
		hitbox.scale.x = 1
	else:
		animated_sprite.flip_h = true
		animated_sprite.offset.x = -offset
		hitbox.scale.x = -1
	position.y = player.position.y
	position.x = player.position.x
	animated_sprite.play()
	timer.start(1.8)
	await timer.timeout
	queue_free()
