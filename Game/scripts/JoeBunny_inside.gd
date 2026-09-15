extends CharacterBody2D

enum States { WALK, ATTACK, JUMP }

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var collision = $CollisionShape2D
@onready var timer = $Timer
@onready var parent = get_parent()

var damage = 1
var speed = 25
var timer_start = false
var direction
var start = false
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var state = States.WALK
var target
var fall = false

func _ready():
	animated_sprite.visible = false

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	elif fall:
		state = States.WALK
		fall = false
	move_and_slide()

func _process(delta):
	if parent.fase2 and not timer_start and not start:
		timer_start = true
		timer.start(2.8)
		await timer.timeout
		var old_global_transform = global_transform
		var scene = get_parent().get_parent()
		get_parent().remove_child(self)
		scene.add_child(self)
		global_transform = old_global_transform
		animated_sprite.visible = true
		target = get_parent().get_node("Player") 
		start = true
		timer_start = false
	if start:
		direction = target.position.x - position.x
		if abs(direction) <= 7 and is_on_floor():
			if target.position.y + 20 < position.y and state != States.JUMP and not fall:
				state = States.JUMP
			elif state != States.ATTACK:
				state = States.ATTACK
		direction = sign(direction)
		animated_sprite.flip_h = direction < 0
		if direction < 0:
			animated_sprite.offset.x = 0
		else:
			animated_sprite.offset.x = 0
		hitbox.scale.x = -direction
		if not timer_start:	
			state_handler()
		if state == States.ATTACK or state == States.JUMP:
			hitbox.hit(damage)
	
func state_handler():
	velocity.x = 0
	if state == States.WALK:
			velocity.x = sign(direction) * speed
			animated_sprite.play("walk")
	elif state == States.ATTACK:
		animated_sprite.play("attack")
		timer.start(0.6)
		timer_start = true
		await timer.timeout
		timer_start = false
		state = States.WALK
	elif state == States.JUMP:
		if not fall:
			animated_sprite.play("jump")
			timer.start(0.2)
			timer_start = true
			await timer.timeout
			velocity.y = -300
			timer.start(0.4)
			await timer.timeout
			timer_start = false
			fall = true
