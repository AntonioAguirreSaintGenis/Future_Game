extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var target: CharacterBody2D = get_parent().get_node("Player") 
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox
@onready var collision = $CollisionShape2D
@onready var timer = $Timer
@onready var barr = get_tree().get_current_scene().get_node("CanvasLayer/Boss_barr")

var health = 15
var damage = 1
var speed = 250
var timer_start
var direction
var fase2 = false
var fall = true
var flying = false
var col
var ori
var bouncing = false
var max_angle = 30.0
var min_flip_distance = 80.0

var rng = RandomNumberGenerator.new()


var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	direction = sign(target.position.x - position.x)
	ori = get_ori(direction, max_angle)
	#animated_sprite.flip_v = target.global_position.x < global_position.x	
	animated_sprite.flip_v = ori.x < 0
	animated_sprite.play("base")
	timer.start(0.6)
	await timer.timeout
	animated_sprite.play("springForward")
	flying = true

func _physics_process(delta):
	if not is_on_floor() and not flying:
		velocity.y += gravity * delta
	if flying:
		velocity = Vector2(max(ori[0] * speed, 250 * direction), ori[1] * speed)
		hitbox.hit(damage)
	else:
		velocity.x = 0
		velocity.y = 0

	move_and_slide()

func _process(delta):
	col = get_last_slide_collision()
	if not bouncing:
		if not fase2 and health < 8:
			fase2 = true
			bouncing = true
			flying = false
			direction = sign(target.position.x - position.x)
			if direction == 1:
				animated_sprite.flip_h = false
				animated_sprite.rotation = 0
			elif direction == -1:
				animated_sprite.flip_h = true
				animated_sprite.rotation = 3.14159
			#animated_sprite.flip_v = target.global_position.x < global_position.x
			animated_sprite.play("faseChange")
			timer.start(2.8)
			await timer.timeout
			ori = get_ori(direction, max_angle)
			animated_sprite.rotation = ori.angle()
			animated_sprite.flip_h = false
			animated_sprite.flip_v = ori.x < 0
			animated_sprite.play("springForward2")
			flying = true
			bouncing = false
		elif is_on_wall() and col != null and col.get_collider() is TileMap:
			bounce()
		elif is_on_floor() or is_on_ceiling():
			if direction == 1:
				animated_sprite.rotation = 0
			elif direction == -1:
				animated_sprite.rotation = 3.14159
	#hitbox.hit(damage)

func bounce():
	bouncing = true
	animated_sprite.flip_h = false
	flying = false
	if not fase2:
		animated_sprite.play("springForwardBack")
	else:
		animated_sprite.play("springForwardBack2")
	if not timer_start:
		timer.start(0.6)
		timer_start = true
		await timer.timeout
		if not fase2:
			animated_sprite.play("springForward")
		else:
			animated_sprite.play("springForward2")
		direction = -direction
		ori = get_ori(direction, max_angle)
		animated_sprite.flip_v = ori.x < 0
		animated_sprite.rotation = ori.angle()
		#animated_sprite.flip_v = target.global_position.x < global_position.x
		#animated_sprite.look_at(target.global_position)
		timer.start(0.6)
		await timer.timeout
		flying = true
		timer_start = false
		bouncing = false

func get_ori(forced_direction: int, max_angle_deg: float) -> Vector2:
	var raw = global_position.direction_to(target.global_position)
	var max_angle = deg_to_rad(max_angle_deg)
	var vertical_angle = clamp(atan2(abs(raw.y), abs(raw.x) if raw.x != 0 else 1.0), 0.0, max_angle)
	var y_sign = 1.0 if raw.y >= 0 else -1.0
	return Vector2(cos(vertical_angle) * forced_direction, sin(vertical_angle) * y_sign)

func take_damage(damage):
	health -= damage
	barr.change_health()
	if health <= 0:
		barr.queue_free()
		queue_free()
