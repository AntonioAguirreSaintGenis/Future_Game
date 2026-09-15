extends CharacterBody2D

enum States {IDLE, ATTACK1, ATTACK2, GO_UP, CHOOSE_ATTACK }

@onready var animated_sprite = $AnimatedSprite2D
@onready var target: CharacterBody2D = get_parent().get_node("Player")
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox_enemy2
@onready var collision = $CollisionShape2D
@onready var timer2 = $Timer2
@onready var timer3 = $Timer3

var rng = RandomNumberGenerator.new()
var random_int
var state = States.IDLE
var health = 2
var damage = 1
var speed = 10
var timer_start
var time =  PI / 2
var direction = 1
var base_position
var state_attack
var x
var y
var can_be_hit = true

func _ready():
	base_position = position
	timer3.wait_time = 5
	timer3.start()

func _physics_process(delta):
	if state == States.IDLE:
		animated_sprite.play("idle")
		time += delta
		velocity.x = speed * direction
		velocity.y = sin(time) * speed
		if sin(time) > 0.99:
			direction *= -1
			time =  PI / 2 + 0.2
	elif state == States.CHOOSE_ATTACK:
		timer_start = false
		direction = sign(target.position.x - position.x)
		rng.randomize()
		random_int = rng.randi_range(1, 3)
		if random_int == 1:
			state = States.ATTACK1
		elif random_int > 1:
			state = States.ATTACK2
	elif state == States.ATTACK1:
		handle_attack(1, 3, 1, hitbox)
		hitbox.hit(damage)
	elif state == States.ATTACK2:
		handle_attack(1, 3, 2, hitbox)
		hitbox.hit(damage)
	elif state == States.GO_UP:
		position.y = move_toward(position.y, -50, speed/5 * delta * 10)
		if position.y == -50:
			rng.randomize()
			random_int = rng.randi_range(5, 7)
			timer3.wait_time = random_int
			state = States.IDLE
	move_and_slide()


func handle_attack(time1, time2, nb_attack, hitbox):
	var timer 
	var pos
	if not timer_start:
		velocity = Vector2(0, 0)
		state_attack = "preparation_%d"%[nb_attack]
		animated_sprite.play(state_attack)
		timer_start = true
		timer = get_tree().create_timer(time1)
		await timer.timeout
		state_attack = "idle"
		x = target.position.x
		y = target.position.y
		if nb_attack == 2:
			hitbox.collision_mask = 1 + 2
	elif state_attack == "idle":
		animated_sprite.play("idle")
		pos = (Vector2(x, y) - position)
		if nb_attack == 1:
			x = target.position.x
			y = target.position.y
			pos = (Vector2(x, y) - position)
			if pos.length() >= speed/10:
				position += pos.normalized() * (speed/10)
		else:
			if pos.length() >= speed/10:
				position += pos.normalized() * (speed/10)
			timer = get_tree().create_timer(time2)
			await timer.timeout
			state = States.GO_UP
			hitbox.collision_mask = 2
			

func _on_timer_timeout():
	state = States.CHOOSE_ATTACK
	
func hitable():
	return can_be_hit

func take_damage(damage):
	can_be_hit = false
	timer2.start(1)
	health -= damage
	if health <= 0:
		queue_free()

func _on_timer_2_timeout():
	can_be_hit = true
