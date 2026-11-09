extends Area2D

@export_range(0, 720) var max_turn_deg := 90.0  # max turn per second, in degrees
@export_range(0, 90) var max_angle_deg := 75.0   # max deviation from horizontal, up or down

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var timer = $Timer

const SPEED = 120
const DAMAGE = 1
const MUZZLE_OFFSET := Vector2(10, -14)

var start = false
var direction = 0
var target
var angle := 0.0

func _ready():
	var enemy = get_parent()
	direction = enemy.direction
	target = enemy.target
	position = Vector2(MUZZLE_OFFSET.x * direction, MUZZLE_OFFSET.y)
	animated_sprite.play("idle")

func _physics_process(delta):
	if start:
		attack(delta)
	elif animated_sprite.animation != "collide":
		direction = get_parent().direction
		animated_sprite.flip_h = direction > 0
		position.x = MUZZLE_OFFSET.x * direction
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	hitbox.hit(DAMAGE)

func start_shot():
	var gp = global_position
	top_level = true          # ignore the parent's transform from now on
	global_position = gp
	start = true
	direction = get_parent().direction
	angle = 0.0
	animated_sprite.flip_h = direction > 0
	hitbox.scale.x = -1 if direction > 0 else 1
	if not get_parent().animated_sprite.flip_h:
		animated_sprite.flip_h = false
		#animated_sprite.offset.x = offset
		hitbox.scale.x = 1
	else:
		animated_sprite.flip_h = true
		#animated_sprite.offset.x = -offset
		hitbox.scale.x = -1

func attack(delta):
	if is_instance_valid(target):
		var to_target = global_position.direction_to(target.global_position)
		# Mirror x so "forward" is always +x
		var wanted = Vector2(to_target.x * direction, to_target.y).angle()
		# Only steer when the target is inside the allowed cone
		if absf(wanted) <= deg_to_rad(max_angle_deg):
			angle = move_toward(angle, wanted, deg_to_rad(max_turn_deg) * delta)
	global_position += Vector2(cos(angle) * direction, sin(angle)) * SPEED * delta
	rotation = angle * direction

func _on_body_entered(body):
	if body != get_parent() and start != false:
		start = false
		timer.start(0.4)
		animated_sprite.play("collide")
		await timer.timeout
		queue_free()
