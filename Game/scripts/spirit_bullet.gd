extends Area2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D
@onready var hitbox = $Hitbox
@onready var timer = $Timer
var spell_cast = false
var do_damage = false
var damage = 1
var offset = 20
var cost = 1
var speed = 200
var direction = 0
var player = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if spell_cast:
		position.x += speed * delta * direction
	if do_damage:
		hitbox.hit(damage)

func start_spell(_player):
	player = _player
	if not player.animated_sprite.flip_h:
		direction = 1
	else:
		direction = -1
	scale.x = direction 
	global_position.y = player.global_position.y
	global_position.x = player.global_position.x + (20 * direction)
	animated_sprite.play("start")
	timer.start(0.8)
	await timer.timeout
	animated_sprite.play("move")
	spell_cast = true
	
func _on_body_entered(body):
	if body != player:
		do_damage = true
		spell_cast = false
		timer.start(0.8)
		animated_sprite.play("collide")
		await timer.timeout
		queue_free()

func _on_area_entered(area):
	if area.get_parent() != player and area != hitbox:
		spell_cast = false
		timer.start(0.8)
		animated_sprite.play("collide")
		await timer.timeout
		queue_free()
