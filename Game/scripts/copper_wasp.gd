extends CharacterBody2D

enum States { IDLE, ATTACKING, CHOOSE_ATTACK, MOVING_VERTICALLY }

@export var acid: PackedScene = preload("res://scenes/bosses/copper_wasp_shot.tscn")

@onready var animated_sprite = $AnimatedSprite2D
@onready var target: CharacterBody2D = get_parent().get_node("Player") 
@onready var hitbox = $Hitbox
@onready var hurtbox1 = $Hurtbox1
@onready var hurtbox2 = $Hurtbox2
@onready var collision = $CollisionShape2D
@onready var timer = $Timer
@onready var timer2 = $Timer2
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
var direction_x
var direction_y
var is_attacking = false
var fall
var collision_start_position_x
var wall_adjusting = false
var can_be_hit = true

func _ready():
	collision_start_position_x = collision.position.x
	rng.randomize()
	random_int = rng.randi_range(1, 3)
	#direction_x = sign(target.position.x - position.x)
	l = []
	next_list = ["attack1", "attack2", "attack3", "attack4", "attack5"]


func _physics_process(_delta):
	if state == States.IDLE:
		direction_x = target.position.x - position.x
		if abs(direction_x) > 64:
			velocity.x = sign(direction_x) * speed
		else:
			velocity.x = 0
	if state == States.IDLE or state == States.MOVING_VERTICALLY:
		direction_y = target.position.y - position.y
		if abs(direction_y) > 10:
			velocity.y = sign(direction_y) * speed
		else:
			velocity.y = 0
	move_and_slide()

func _process(_delta):
	if state == States.IDLE:
		flip()
		animated_sprite.play("idle")
		if not timer_start:
			timer.start(2)
			timer_start = true
			await timer.timeout
			state = States.CHOOSE_ATTACK
			timer_start = false
	elif state == States.CHOOSE_ATTACK:
		rng.randomize()
		random_int = rng.randi_range(2, 5)
		handle_attacks(random_int)
		state = States.ATTACKING
	elif state == States.ATTACKING or state == States.MOVING_VERTICALLY:
		if is_on_wall():
			if animated_sprite.animation == "attack1_3-2":
				timer.stop()
				timer.timeout.emit()
		if animated_sprite.animation == "attack1_3-2":
			hitbox.hit(damage)
		
func next():
	var nx = l.pop_back()
	if nx == "idle":
		state = States.IDLE
	elif nx == "overcharged":
		overcharged()
	elif nx == "attack1":
		attack1()
	elif nx == "attack2":
		attack2()
	elif nx == "attack3":
		attack3()
	elif nx == "attack4":
		attack4()
	elif nx == "attack5":
		attack5()

func handle_attacks(random_int):
	var i = random_int
	l = []
	l.append("idle")
	while i != 0:
		random_int = rng.randi_range(0, 4)
		while l[len(l) - 1] == next_list[random_int]:
			random_int = rng.randi_range(0, 2)
		l.append(next_list[random_int])
		i-=1
	state = States.ATTACKING
	next()

func overcharged():
	pass
func attack1():
	flip()
	velocity.x = 0
	velocity.y = 0
	damage = 1
	hitbox.collision_mask = 1 + 2
	animated_sprite.play("attack1-1")
	if not timer_start:
		timer.start(0.6)
		timer_start = true
		await timer.timeout
		animated_sprite.play("attack1_3-2")
		direction_y = target.position.y - position.y
		if abs(target.global_position.y - global_position.y) > 10:
			state = States.MOVING_VERTICALLY
		while abs(target.global_position.y - global_position.y) > 10:
			await get_tree().physics_frame
		state = States.ATTACKING
		#collision_layer = 4
		timer.start(2)
		velocity.y = 0
		velocity.x = speed * direction_x * 6
		await timer.timeout
		#collision_layer = 3
		timer_start = false
		next()
func attack2():
	flip()
	velocity.x = 0
	velocity.y = 0
	hitbox.collision_mask = 2
	damage = 2
	animated_sprite.play("attack3-1")
	if not timer_start:
		timer.start(0.6)
		timer_start = true
		await timer.timeout
		flip()
		velocity.x = speed * direction_x * 3
		animated_sprite.play("idle")
		state = States.MOVING_VERTICALLY
		timer.start(0.6)
		await timer.timeout
		state = States.ATTACKING
		animated_sprite.play("attack1_3-2")
		velocity.x = speed/2 * direction_x
		velocity.y = 0
		timer.start(0.6)
		await timer.timeout
		flip()
		velocity.x = speed * direction_x * 3
		animated_sprite.play("idle")
		state = States.MOVING_VERTICALLY
		timer.start(0.6)
		await timer.timeout
		state = States.ATTACKING
		animated_sprite.play("attack1_3-2")
		velocity.x = speed/2 * direction_x
		velocity.y = 0
		timer.start(0.6)
		await timer.timeout
		timer_start = false
		next()
func attack3():
	flip()
	animated_sprite.play("attack2")
	if not timer_start:
		velocity.x = 0
		velocity.y = 0
		timer.start(0.6)
		timer_start = true
		await timer.timeout
		var shot = acid.instantiate()
		if direction_x < 0:
			shot.position = Vector2(position.x - 1, position.y - 11)
		else:
			shot.position = Vector2(position.x + 1, position.y - 11)
		get_parent().add_child(shot)
		direction_x = sign(target.position.x - position.x)
		timer.start(0.2)
		await timer.timeout
		timer_start = false
		next()
func attack4():
	if not timer_start:
		var i = rng.randi_range(2, 4)
		while i != 0:
			flip()
			animated_sprite.play("attack2")
			velocity.x = 0
			velocity.y = 0
			timer.start(0.6)
			timer_start = true
			await timer.timeout
			var shot = acid.instantiate()
			if direction_x < 0:
				shot.position = Vector2(position.x - 1, position.y - 11)
			else:
				shot.position = Vector2(position.x + 1, position.y - 11)
			get_parent().add_child(shot)
			direction_x = sign(target.position.x - position.x)
			timer.start(0.2)
			await timer.timeout
			i -=1
		timer_start = false	
		next()
func attack5():
	flip()
	velocity.x = 0
	velocity.y = 0
	damage = 1
	hitbox.collision_mask = 1 + 2
	animated_sprite.play("attack1-1")
	if not timer_start:
		timer.start(0.6)
		timer_start = true
		await timer.timeout
		animated_sprite.play("attack1_3-2")
		direction_y = target.position.y - position.y
		if abs(target.global_position.y - global_position.y) > 10:
			state = States.MOVING_VERTICALLY
		while abs(target.global_position.y - global_position.y) > 10:
			await get_tree().physics_frame
		state = States.ATTACKING
		#collision_layer = 4
		timer.start(2)
		velocity.y = 0
		velocity.x = speed * direction_x * 6
		await timer.timeout
		flip()
		#collision_layer = 1
		direction_y = target.position.y - position.y
		if abs(target.global_position.y - global_position.y) > 10:
			state = States.MOVING_VERTICALLY
		while abs(target.global_position.y - global_position.y) > 10:
			await get_tree().physics_frame
		state = States.ATTACKING
		#collision_layer = 4
		timer.start(2)
		velocity.y = 0
		velocity.x = speed * direction_x * 6
		await timer.timeout
		#collision_layer = 1
		timer_start = false
		next()

func flip():
	direction_x = sign(target.position.x - position.x)
	animated_sprite.flip_h = direction_x < 0
	collision.position.x = collision_start_position_x * direction_x
	hitbox.scale.x = direction_x
	hurtbox1.scale.x = direction_x
	hurtbox2.scale.x = direction_x
	if is_on_wall():
		if not wall_adjusting:
			wall_adjusting = true
			var tween = create_tween()
			tween.tween_property(self, "position:x", position.x + direction_x * 20, 0.12)
			await tween.finished
			wall_adjusting = false
	
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
