extends CharacterBody2D

enum States {IDLE, ATTACK1, ATTACK2, GO_UP, CHOOSE_ATTACK }
enum Phase { WINDUP, ACTIVE, RECOVER }

@onready var animated_sprite = $AnimatedSprite2D
@onready var target: CharacterBody2D = get_parent().get_node("Player")
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox_enemy2
@onready var collision = $CollisionShape2D
@onready var timer2 = $Timer2
@onready var timer3 = $Timer3

const HOVER_HEIGHT := 50.0   # how far above its spawn point it hovers
const RISE_SPEED := 30.0     # px per second
const WINDUP_TIME := 1.0       # stands still while the "preparation" animation plays
const FOLLOW_SPEED := 45.0     # attack 1: slow chase (px/s)
const FOLLOW_TIME := 5.0       # attack 1: how long it keeps chasing
const SPRINT_SPEED := 100.0    # attack 2: fast dash (px/s)
const SPRINT_MAX_TIME := 1.5   # attack 2: safety, gives up if it never reaches the point
const SPRINT_PAUSE := 0.5      # attack 2: pause after arriving, before going back up

var phase := Phase.WINDUP
var phase_time := 0.0
var attack_point := Vector2.ZERO
var default_hitbox_mask: int
var hover_y := 0.0
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
var agro = false
var attack_timer_started = false
var start_state = States.CHOOSE_ATTACK
var pos = Vector2i(-1, -1)
var room_cell = Vector2i(-1, -1)
var difficulty = 1
var id

func _ready():
	timer3.one_shot = true   # otherwise it re-fires and forces CHOOSE_ATTACK mid-attack
	default_hitbox_mask = hitbox.collision_mask

func _physics_process(delta):
	if state == States.IDLE:
		animated_sprite.play("idle")
		time += delta
		velocity.x = speed * direction
		velocity.y = sin(time) * speed
		if sin(time) > 0.99:
			direction *= -1
			time = PI / 2 + 0.2
	elif state == States.CHOOSE_ATTACK:
		direction = sign(target.position.x - position.x)
		rng.randomize()
		state = States.ATTACK1 if rng.randi_range(1, 3) == 1 else States.ATTACK2
		start_attack()
	elif state == States.ATTACK1 or state == States.ATTACK2:
		update_attack(delta)
	elif state == States.GO_UP:
		velocity = Vector2.ZERO
		position.y = move_toward(position.y, hover_y, RISE_SPEED * delta)
		if is_equal_approx(position.y, hover_y):
			rng.randomize()
			timer3.start(rng.randf_range(2, 3))
			state = States.IDLE
	move_and_slide()

func start_attack():
	phase = Phase.WINDUP
	phase_time = 0.0
	velocity = Vector2.ZERO
	hitbox.collision_mask = default_hitbox_mask
	animated_sprite.play("preparation_1" if state == States.ATTACK1 else "preparation_2")


func update_attack(delta):
	phase_time += delta
	# wind-up: stand still, harmless
	if phase == Phase.WINDUP:
		velocity = Vector2.ZERO
		if phase_time >= WINDUP_TIME:
			phase = Phase.ACTIVE
			phase_time = 0.0
			animated_sprite.play("idle")
			if state == States.ATTACK2:
				attack_point = target.position        # locked in: the sprint goes here
				hitbox.collision_mask = 1 + 2
		return
	# only dangerous after the wind-up
	hitbox.hit(damage)
	if phase == Phase.RECOVER:                        # short pause after the sprint
		velocity = Vector2.ZERO
		if phase_time >= SPRINT_PAUSE:
			finish_attack()
	elif state == States.ATTACK1:
		follow_player()
		if phase_time >= FOLLOW_TIME:
			finish_attack()
	else:
		sprint(delta)

func follow_player():
	var to_target = target.position - position
	if to_target.length() > 4.0:     # avoids jitter when right on top of the player
		velocity = to_target.normalized() * FOLLOW_SPEED
	else:
		velocity = Vector2.ZERO

func sprint(delta):
	var to_point = attack_point - position
	if to_point.length() <= SPRINT_SPEED * delta:
		velocity = to_point / delta              # last step lands exactly on the point
		phase = Phase.RECOVER
		phase_time = 0.0
	elif phase_time >= SPRINT_MAX_TIME:          # blocked by something, give up
		velocity = Vector2.ZERO
		phase = Phase.RECOVER
		phase_time = 0.0
	else:
		velocity = to_point.normalized() * SPRINT_SPEED

func finish_attack():
	velocity = Vector2.ZERO
	hitbox.collision_mask = default_hitbox_mask
	state = States.GO_UP
	
func hitable():
	return can_be_hit

func take_damage(damage):
	can_be_hit = false
	timer2.start(1)
	health -= damage
	if health <= 0:
		get_parent().delete_enemy(room_cell, id)
		queue_free()

func _on_timer_2_timeout():
	can_be_hit = true

func _on_timer_3_timeout():
	state = States.CHOOSE_ATTACK

func set_pos(x, y, room_size, layers, new_id):
	var half = room_size / 2
	# a column on the left side, between the wall layers and just before the middle
	var local_x = rng.randi_range(layers + 1, maxi(layers + 1, half - 3))
	if rng.randf() < 0.5:
		local_x = room_size - 1 - local_x   # mirror it to the right side
	# just above the deepest possible floor stack (wall row + `layers` layers)
	var local_y = room_size - 2 - layers
	room_cell = Vector2i(x, y)
	pos = Vector2i(x * room_size + local_x, y * room_size + local_y)   # tile coordinate
	id = new_id

func generate():
	var tilemap = get_parent()
	position = tilemap.map_to_local(pos)
	hover_y = position.y - HOVER_HEIGHT

func de_generate():
	queue_free()
