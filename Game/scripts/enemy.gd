extends CharacterBody2D

enum States { IDLE, WALK, ATTACK1, ATTACK2, CHOOSE_ATTACK }

@onready var animated_sprite = $AnimatedSprite2D
@onready var target: CharacterBody2D = get_parent().get_node("Player") 
@onready var detection = $Detection
@onready var hitbox1 = $Hitbox1
@onready var hitbox2 = $Hitbox2
@onready var hurtbox = $Hurtbox_enemy1
@onready var collision = $CollisionShape2D
@onready var timer2 = $Timer2

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

func _ready():
	rng.randomize()
	random_int = rng.randi_range(1, 3)
	
func _physics_process(delta):
	direction = target.position.x - position.x
	if state == States.WALK:
		if abs(direction) > 20:
			velocity.x = sign(direction) * speed
		else:
			state = States.CHOOSE_ATTACK
		direction = sign(direction)
		animated_sprite.play("idle")
		animated_sprite.flip_h = direction > 0
		animated_sprite.offset.x = direction * 5
		hitbox1.scale.x = -direction
		hitbox2.scale.x = -direction
	else:
		velocity.x = 0
		if state == States.CHOOSE_ATTACK:
			timer_start = false
			rng.randomize()
			random_int = rng.randi_range(1, 3)
			if random_int == 1:
				state = States.ATTACK2
			elif random_int > 1:
				state = States.ATTACK1
		elif state == States.ATTACK1:
			handle_attack(0.7, 0.5, "attack1", 2, 7, hitbox1)
		elif state == States.ATTACK2:
			handle_attack(0.7, 0.5, "attack2", 0, 15, hitbox2)
		else:
			animated_sprite.play("idle")
			
	move_and_slide()

#attack is an str wich has for value either attack1 or attack2
func handle_attack(time1, time2, attack, frame1, frame2, hitbox):
	var timer
	if animated_sprite.animation != attack:
		animated_sprite.play(attack)
	elif animated_sprite.frame ==  frame1 and not timer_start:
			timer_start = true
			animated_sprite.pause()
			timer = get_tree().create_timer(time1)
			await timer.timeout
			animated_sprite.frame += 1
			if attack == "attack2":
				hitbox2.hit(damage)
				hitbox.collision_mask = 1 + 2
			else:
				hitbox1.hit(damage)
			animated_sprite.play()
	elif animated_sprite.frame == frame2:
			animated_sprite.pause()
			timer = get_tree().create_timer(time2)
			await timer.timeout
			state = States.WALK
			hitbox.collision_mask = 2	

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


func _on_detection_body_entered(body):
	if body == target and agro == false:
		state = States.WALK
		agro = true # Replace with function body.
