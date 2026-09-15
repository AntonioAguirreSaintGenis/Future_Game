extends CharacterBody2D

enum States { IDLE, ATTACKING, CHOOSE_ATTACK }

@onready var animated_sprite = $AnimatedSprite2D
@onready var target: CharacterBody2D = get_parent().get_node("Player") 
@onready var hitbox1 = $Hitbox1
@onready var hitbox2 = $Hitbox2
@onready var hitbox3 = $Hitbox3
@onready var hurtbox = $Hurtbox
@onready var collision = $CollisionShape2D
@onready var timer = $Timer
@onready var timer2 = $Timer2
@onready var magic = $Magic
@onready var barr = get_tree().get_current_scene().get_node("CanvasLayer/Boss_barr")

var rng = RandomNumberGenerator.new()
var random_int
var state = States.IDLE
var health = 15
var damage = 1
var speed = 50
var l
var next_list
var timer_start
var direction
var hitbox
var is_attacking = false
var fall
var can_be_hit = true

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	rng.randomize()
	random_int = rng.randi_range(1, 3)
	direction = sign(target.position.x - position.x)
	hitbox = hitbox1
	l = []
	next_list = ["attack1", "attack2", "attack3"]
	magic.get_node("AnimatedSprite2D").visible = false


func _physics_process(delta):
	if not is_on_floor() and fall:
		velocity.y += gravity * delta

	move_and_slide()

func _process(delta):
	animated_sprite.flip_h = direction > 0
	hitbox1.scale.x = -direction
	hitbox2.scale.x = -direction
	hitbox3.scale.x = -direction
	if state == States.IDLE:
		animated_sprite.play("idle")
		if not timer_start:
			timer.start(0.4)
			timer_start = true
			await timer.timeout
			state = States.CHOOSE_ATTACK
			timer_start = false
	elif state == States.CHOOSE_ATTACK:
		rng.randomize()
		random_int = rng.randi_range(1, 5)
		handle_attacks(random_int)
		state = States.ATTACKING
	elif state == States.ATTACKING:
		if animated_sprite.animation == "attack1-2" or animated_sprite.animation == "attack2-2" or animated_sprite.animation == "attack3-1" or animated_sprite.animation == "attack3-2":
			hitbox.hit(damage)
		
func next():
	var nx = l.pop_back()
	if nx == "idle":
		state = States.IDLE
	elif nx == "attack1":
		attack1()
	elif nx == "attack2":
		attack2()
	elif nx == "attack3":
		attack3()
	elif nx == "teleport1":
		teleport(0)
	elif nx == "teleport2":
		fall = false
		teleport(50)

func handle_attacks(random_int):
	var i = random_int
	l = []
	l.append("idle")
	while i != 0:
		random_int = rng.randi_range(0, 2)
		while l[len(l) - 1] == next_list[random_int]:
			random_int = rng.randi_range(0, 2)
		l.append(next_list[random_int])
		if random_int == 1:
			l.append("teleport2")
		i-=1
	l.append("teleport1")
	state = States.ATTACKING
	next()

func teleport(nb):
	animated_sprite.play("teleport")
	if not timer_start:
		timer.start(0.6)
		timer_start = true
		await timer.timeout
		if fall:
			position.x = target.position.x - 40 * direction
		else:
			position. x = target.position.x
		if nb != 0:
			position.y = target.position.y - nb
		timer.start(0.65)
		await timer.timeout
		timer_start = false
		fall = true
		next()
		
func attack1():
	direction = sign(target.position.x - position.x)
	damage = 1
	hitbox = hitbox1
	animated_sprite.play("attack1-1")
	if not timer_start:
		timer.start(1)
		timer_start = true
		await timer.timeout
		animated_sprite.play("attack1-2")
		timer.start(0.4)
		await timer.timeout
		"timer.start(0.4)
		await timer.timeout"
		timer_start = false
		next()
func attack2():
	direction = sign(target.position.x - position.x)
	damage = 2
	collision_layer = 4
	hitbox = hitbox2
	animated_sprite.play("attack3-1")
	while not is_on_floor():
		await get_tree().physics_frame
	collision_layer = 1
	animated_sprite.play("attack3-2")
	timer.start(0.5)
	timer_start = true
	await timer.timeout
	timer_start = false
	next()
func attack3():
	direction = sign(target.position.x - position.x)
	damage = 2
	hitbox = hitbox3
	animated_sprite.play("attack2-1")
	if not timer_start:
		timer.start(1)
		timer_start = true
		await timer.timeout
		animated_sprite.play("attack2-2")
		magic.get_node("AnimatedSprite2D").visible = true
		magic.get_node("AnimatedSprite2D").play()
		timer.start(0.5)
		await timer.timeout
		magic.get_node("AnimatedSprite2D").visible = false
		timer_start = false
		next()
		
func hitable():
	return can_be_hit

func take_damage(damage):
	can_be_hit = false
	timer2.start(0.75)
	health -= damage
	barr.change_health()
	if health <= 0:
		barr.queue_free()
		queue_free()

func _on_timer_2_timeout():
	can_be_hit = true
