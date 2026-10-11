extends Area2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision = $CollisionShape2D
@onready var hitbox = $Hitbox
@onready var timer = $Timer
@onready var timer2 = $Timer2
@onready var timer3 = $Timer3
var spell_cast = false
var work = true
var damage = 1
var offset = 20
var cost = 5
var speed = 35
var direction = 0
var player = null
var name_laser = load("res://scenes/spells/laser.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if spell_cast and work:
		position.x += speed * delta * direction
	hitbox.hit(damage)

func start_spell(_player):
	player = _player
	timer2.start(10)
	timer3.start(randi_range(1, 3))
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

func _on_timer_2_timeout():
	spell_cast = false
	timer.start(0.8)
	animated_sprite.play("collide")
	await timer.timeout
	queue_free()


func _on_timer_3_timeout():
	var laser = name_laser.instantiate()
	spell_cast = false
	get_parent().add_child(laser)
	laser.rotation += randf_range(0.0, 360.0)
	laser.offset = 61
	laser.start_spell(self)
	timer3.start(randi_range(3, 4))
	timer.start(0.5)
	await timer.timeout
	spell_cast = true

func _on_body_entered(body):
	work = false
