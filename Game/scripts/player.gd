extends CharacterBody2D


const SPEED = 100.0
const CHARGE_THRESHOLD = 2

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@export var jump_height: float
@export var jump_time_to_peak: float
@export var jump_time_to_descend: float

@onready var jump_velocity: float = ((2.0 * jump_height)/jump_time_to_peak) * -1.0
@onready var jump_gravity: float = ((-2.0 * jump_height)/(jump_time_to_peak*jump_time_to_peak)) * -1.0
@onready var fall_gravity: float = ((-2.0 * jump_height)/(jump_time_to_descend*jump_time_to_descend)) * -1.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox_player
@onready var collision = $CollisionShape2D
@onready var timer = $Timer
@onready var timer2 = $Timer2
@onready var magic = get_parent().get_node("Spell_handler")
#@onready var blood = $CPUParticles2D

var direction = 1
var health = 3
var mana = 1
var rage = 6
var state = "idle"
var spell = "fire"
var damage = 1
var double_jump = false
var wall_jump = false
var dashing = false
var priority = 4
var col
var jumping
var timer_wall_and_jump = 0.0
var can_be_hit = true

func _ready():
	hurtbox.monitorable = true
	
func _physics_process(delta):
	#x velocity
	direction = Input.get_axis("move_left", "move_right")
	if priority != 0:
		if state != "wall":
			if direction != 0:
				animated_sprite.flip_h = (direction < 0)
				if direction < 0:
					animated_sprite.offset.x = -3
					hitbox.scale.x = -1 
				else:
					animated_sprite.offset.x = 3
					animated_sprite.scale.x = 1
					hitbox.scale.x = 1 
			velocity.x = direction * SPEED
		else:
			if col:
				velocity.x = -col.get_normal().x * 10
	elif state == "dash":
		if animated_sprite.flip_h:
			direction = -1
		else:
			direction = 1
		velocity.x = direction * SPEED * 2
		col = get_last_slide_collision()
		if animated_sprite.frame > 0:
			if not is_on_floor() and is_on_wall() and col and col.get_collider() is TileMap:
				state = "wall"
				priority = 3
				wall()
	else:
			velocity.x = move_toward(velocity.x, 0, SPEED*delta*2)

	
	#y velocity
	if state == "attack" and velocity.y >= 0:
		velocity.y += (get_gravity() * delta)/2
	elif state == "wall":
		velocity.y = 10
		if not is_on_wall():
			timer_wall_and_jump += delta
			if timer_wall_and_jump > 0.3:
				state = "fall"
				animated_sprite.play("fall")
				wall_jump = false
		else:
			timer_wall_and_jump = 0.0
	elif state == "charge jump":
		if direction == 0:
			timer_wall_and_jump += delta
			if timer_wall_and_jump >= 0.2:
				charge_jump()
			if Input.is_action_just_released("jump"):
				if timer_wall_and_jump < CHARGE_THRESHOLD:
					velocity.y = jump_velocity
					state = "jump"
					animated_sprite.play("jump")
					timer_wall_and_jump = 0.0
				else:
					velocity.y = jump_velocity * 1.5
					state = "flying"
					flying()
					timer_wall_and_jump = 0.0
		else:
			priority = 4
	elif state == "magic":
		velocity.y += (get_gravity() * delta)/6
	elif state == "flying" and is_on_ceiling():
		state = "fall"
		animated_sprite.play("fall")
	elif not is_on_floor() and state != "dash" and state != "flying" and state != "magic":
		velocity.y += get_gravity() * delta
	
	if priority > 0:
		if Input.is_action_just_pressed("attack"):
			state = "attack"
			priority = 0
			attack()
		elif Input.is_action_just_pressed("dash"):
			if not dashing:
				state = "dash"
				priority = 0
				dash()
		elif Input.is_action_just_pressed("magic"):
			if mana == 2 or rage >= 3: 
				state = "magic"
				priority = 0
				doMagic()
		elif Input.is_action_just_pressed("potion") and is_on_floor():
			state = "potion"
			priority = 0
			potion()
		elif Input.is_action_just_pressed("block"):
			state = "block"
			priority = 0
			block()
	if priority > 1:
		if is_on_floor():
			if Input.is_action_just_pressed("jump"):
				if Input.is_action_pressed("down"):
					state = "charge jump"
					timer_wall_and_jump = 0.0
				else:
					state = "jump"
					jump()
				priority = 2
		else:
			if Input.is_action_just_pressed("jump"):
				if state == "wall":
					state = "wall_jump"
					doWallJump()
				elif double_jump == false:
					state = "double_jump"
					doDouble_jump()
				priority = 2
	if priority > 2:
		col = get_last_slide_collision()
		if not is_on_floor() and is_on_wall() and col and col.get_collider() is TileMap:
			state = "wall"
			priority = 3
			wall()
	if priority > 3:
		if Input.is_action_pressed("move_left") and is_on_floor():
			state = "move_left"
			priority = 4
			move_left()
		elif Input.is_action_pressed("move_right") and is_on_floor():
			state = "move_right"
			priority = 4
			move_right()
		elif direction == 0 and is_on_floor():
			state = "idle"
			priority = 4
			idle()
	
	move_and_slide()
	
	if is_on_floor():
		wall_jump = false
		dashing = false
	if is_on_wall():
		dashing = false
	
func attack():
	hitbox.hit(damage)
	animated_sprite.play("attack")
func block():
	can_be_hit = false
	animated_sprite.play("block")
	timer.start(0.6)
	await timer.timeout
	can_be_hit = true
func jump():
	double_jump = false
	velocity.y = jump_velocity
	animated_sprite.play("jump")
func charge_jump():
	double_jump = false
	#velocity.y = JUMP_VELOCITY
	animated_sprite.play("charge jump")
func flying():
	animated_sprite.play("flying")
func doDouble_jump():
	if double_jump == false:
		wall_jump = false
		velocity.y = jump_velocity + 50
		double_jump = true
		if is_on_wall():
			animated_sprite.play("fall")
		else:
			animated_sprite.play("double_jump")
func doWallJump():
	wall_jump = false
	velocity.y = jump_velocity
	animated_sprite.play("jump")
func dash():
	if dashing == false:
		hurtbox.collision_layer = 1
		velocity.y = 0
		collision_layer = 2
		collision_mask = 2
		dashing = true
		wall_jump = false
		animated_sprite.play("dash")
func wall():
	double_jump = false
	if wall_jump == false:
		wall_jump = true
		col = get_last_slide_collision()
		if col != null:
			if col.get_normal().x > 0:
				animated_sprite.flip_h = false
				animated_sprite.offset.x = 3
				hitbox.scale.x = 1
			else:
				animated_sprite.flip_h = true
				animated_sprite.offset.x = -3
				hitbox.scale.x = -1
		animated_sprite.play("wall")
func potion():
	if rage == 6:
		rage = 0
		animated_sprite.play("potion")
		health += 1
		mana += 1
func doMagic():
	if magic.spell_cast == false:
		if mana == 2:
			mana = 0
			animated_sprite.play("magic")
			timer.start(0.4)
			await timer.timeout
			magic.cast_spell(2)
		elif rage >= 3:
			rage -= 2
			mana += 1
			animated_sprite.play("magic")
			timer.start(0.4)
			await timer.timeout
			magic.cast_spell(1)
func move_left():
	animated_sprite.play("walk")
func move_right():
	animated_sprite.play("walk")
func idle():
	if is_on_floor():
		animated_sprite.play("idle")
	
func get_gravity():
	return jump_gravity if velocity.y < 0.0 else fall_gravity
		
func _on_animated_sprite_2d_animation_finished():
	hurtbox.collision_layer = 2
	collision_layer = 1
	collision_mask = 1
	hurtbox.monitorable = true
	if state == "dash":
		state = "fall"
		if not is_on_floor():
			animated_sprite.play("fall")
	if (velocity.y > 10 and not is_on_floor() and state != "fall"):
			animated_sprite.play("fall")
			state = "fall"
	priority = 4

func hitable():
	return can_be_hit

func take_damage(damage):
	can_be_hit = false
	timer2.start(1)
	health -= damage
	if health <= 0:
		get_tree().reload_current_scene()

func _on_timer_2_timeout():
	can_be_hit = true
