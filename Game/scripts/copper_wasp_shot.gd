extends Area2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var target: CharacterBody2D = get_parent().get_node("Player")
@onready var timer = $Timer
@onready var hitbox = $Hitbox

var velocity: Vector2 = Vector2.ZERO

var fall_gravity: float = 500.0
var travel_time: float = 1

var timer_start = false
var damage = 1
var hitting = false

func _ready():
	animated_sprite.play("idle")
	var start_position = global_position
	var target_position = target.global_position
	var distance = target_position - start_position
	velocity.x = distance.x / travel_time
	velocity.y = (distance.y / travel_time- 0.5 * fall_gravity * travel_time)

func _physics_process(delta):
	if not timer_start:
		velocity.y += fall_gravity * delta
		position += velocity * delta
	if hitting:
		hitbox.hit(damage)

func _on_body_entered(_body):
	if not timer_start:
		hitting = true
		timer_start = true
		timer.start(0.8)
		animated_sprite.play("break up")
		await timer.timeout
		timer_start = false
		queue_free()
