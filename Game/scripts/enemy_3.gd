extends CharacterBody2D

enum States { IDLE, ATTACK, ATTACKING }

@onready var animated_sprite = $AnimatedSprite2D
@onready var target: CharacterBody2D = get_tree().current_scene.get_node("Player")
@onready var hurtbox = $Hurtbox
@onready var collision = $CollisionShape2D
@onready var timer = $Timer
@onready var timer2 = $Timer2
@onready var shot = "res://scenes/ennemies/enemy_3_shot.tscn"
@onready var detection: CollisionShape2D = $Detection/CollisionShape2D

var rng = RandomNumberGenerator.new()
var random_int
var state = States.IDLE
var health = 3
var damage = 1
var speed = 50
var timer_start
var direction
var can_be_hit = true
var agro = false
var start_state = States.ATTACK
var offset
var pos = Vector2i(-1, -1)
var room_cell = Vector2i(-1, -1)
var difficulty = 2
var id

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	rng.randomize()
	direction = sign(target.global_position.x - global_position.x)
	offset = animated_sprite.offset.x

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	if animated_sprite.animation != "shoot1" and animated_sprite.animation != "shoot2":
		direction = sign(target.global_position.x - global_position.x)
	move_and_slide()

func _process(delta):
	if agro:
		animated_sprite.flip_h = direction > 0
		hurtbox.scale.x = -direction
		if direction < 0:
			animated_sprite.offset.x = offset
		else:
			animated_sprite.offset.x = -offset
		if state == States.IDLE:
			animated_sprite.play("idle")
			if not timer_start:
				timer.start(rng.randi_range(3, 4))
				timer_start = true
				await timer.timeout
				state = States.ATTACK
				timer_start = false
		elif state == States.ATTACK:
			attack()
			state = States.ATTACKING
	else:
		animated_sprite.play("idle")
		
func attack():
	direction = (target.global_position.x - global_position.x)
	direction = sign(direction)
	damage = 1
	animated_sprite.play("charge shot")
	if not timer_start:
		timer.start(3)
		timer_start = true
		await timer.timeout
		#create here
		var new_shot = load(shot).instantiate()
		add_child(new_shot)
		animated_sprite.play("wait shot")
		timer.start(rng.randi_range(1, 2))
		await timer.timeout
		animated_sprite.play("shoot1")
		timer.start(0.4)
		await timer.timeout
		new_shot.start_shot()
		animated_sprite.play("shoot2")
		timer.start(0.2)
		await timer.timeout
		timer_start = false
		state = States.IDLE
		if detection != null and detection.shape is CircleShape2D:
			var radius = detection.shape.radius * detection.global_scale.x
			if abs(target.global_position.x - detection.global_position.x) > radius:
				agro = false
		
func hitable():
	return can_be_hit

func take_damage(damage):
	can_be_hit = false
	timer2.start(0.75)
	health -= damage
	if health <= 0:
		get_parent().delete_enemy(room_cell, id)
		queue_free()

func _on_timer_2_timeout():
	can_be_hit = true

func set_pos(x, y, room_size, layers, new_id):
	var half = room_size / 2
	# a column on the left side, between the wall layers and just before the middle
	var local_x = rng.randi_range(layers + 1, maxi(layers + 1, half/2))
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

func de_generate():
	queue_free()
