extends CharacterBody2D


const SPEED = 100.0
const JUMP_VELOCITY = -300.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
enum States { ATTACK, BLOCK, DASH, IDLE, JUMP, WALK, MAGIC, POTION, WALL }

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox = $Hitbox
@onready var hurtbox = $Hurtbox_player
@onready var collision = $CollisionShape2D
@onready var magic = get_parent().get_node("Spell_handler")
#@onready var blood = $CPUParticles2D

var direction = 1
var health = 3
var mana = 1
var rage = 6
var state = States.IDLE
var spell = "fire"
var damage = 1
var double_jump = false
var wall_jump = false

func _ready():
	hitbox.monitoring = false
	hurtbox.monitorable = true
	
func _physics_process(delta):
	# Add the gravity.
	if state == States.ATTACK:
		velocity.y += (gravity * delta)/2
	elif state == States.WALL:
		velocity.y = 10
	elif not is_on_floor() and state != States.DASH:
		velocity.y += gravity * delta

	# Handle states.
	if state != States.BLOCK and state != States.MAGIC and state != States.POTION:
		if state != States.DASH:
			if Input.is_action_just_pressed("attack"):
				state = States.ATTACK
				hitbox.monitoring = true
				animated_sprite.play("attack")
		if state != States.ATTACK and state != States.DASH:
			if Input.is_action_just_pressed("dash"):
				state = States.DASH
				hurtbox.collision_layer = 1
				velocity.y = 0
				collision_layer = 2
				collision_mask = 2
				animated_sprite.play("dash")
				
		if state != States.DASH and state != States.ATTACK:
			if state != States.POTION and state != States.JUMP:
				if Input.is_action_just_pressed("magic"):
					if magic.spell_cast == false:
						if mana == 2:
							mana = 0
							state = States.MAGIC
							animated_sprite.play("magic")
							magic.cast_spell(2)
						elif rage >= 3:
							rage -= 2
							mana += 1
							state = States.MAGIC
							animated_sprite.play("magic")
							magic.cast_spell(1)
			if state != States.MAGIC:
				if state != States.JUMP and is_on_floor():
					if Input.is_action_just_pressed("potion"):
						if rage == 6:
							rage = 0
							state = States.POTION
							animated_sprite.play("potion")
							health += 1
							mana += 1
				if state != States.POTION:
					if Input.is_action_just_pressed("block"):
						state = States.BLOCK
						hurtbox.monitorable = false
						animated_sprite.play("block")
					elif state != States.BLOCK:
						if Input.is_action_just_pressed("jump"):
							if is_on_floor() and state != States.JUMP:
								velocity.y = JUMP_VELOCITY
								state = States.JUMP
								animated_sprite.play("jump")
								double_jump = false
								wall_jump = false
							elif double_jump == false:
								velocity.y = JUMP_VELOCITY + 50
								state = States.JUMP	
								double_jump = true
								if is_on_wall():
									animated_sprite.play("wall_jump")
								else:
									animated_sprite.play("double_jump")
						elif Input.is_action_pressed("move_left") and is_on_floor():
							direction = -1
							animated_sprite.flip_h = true
							animated_sprite.offset.x = -3
							hitbox.scale.x = -1
							state = States.WALK
							animated_sprite.play("walk")
						elif Input.is_action_pressed("move_right") and is_on_floor():
							direction = 1
							animated_sprite.flip_h = false
							animated_sprite.offset.x = 3
							hitbox.scale.x = 1
							state = States.WALK
							animated_sprite.play("walk")
						elif not is_on_floor() and is_on_wall() and get_last_slide_collision().get_collider() is TileMap:
								state = States.WALL
								double_jump = false
								if wall_jump == false:
									wall_jump = true
									animated_sprite.offset.x *= -1
									hitbox.scale.x *= -1
									direction *= -1
									animated_sprite.flip_h = not animated_sprite.flip_h
									animated_sprite.play("wall")
						elif (state == States.IDLE or not Input.is_anything_pressed()):
							if is_on_floor():
								state = States.IDLE
								animated_sprite.play("idle")
							else:
								animated_sprite.play("fall")

	if state == States.WALK:
		velocity.x = direction * SPEED
	elif state == States.JUMP:
		if wall_jump == false:
			velocity.x = direction * SPEED
			if Input.is_action_pressed("move_left"):
				direction = -1
				animated_sprite.flip_h = true
				animated_sprite.offset.x = -3
				hitbox.scale.x = -1
			elif Input.is_action_pressed("move_right"):
				direction = 1
				animated_sprite.flip_h = false
				animated_sprite.offset.x = 3
				hitbox.scale.x = 1
		else:
			if (not Input.is_action_pressed("move_left") and direction == -1) or (not Input.is_action_pressed("move_right") and direction == 1):
				velocity.x = 0
	elif state == States.DASH:
		velocity.x = direction * SPEED * 2
	#elif state == States.ATTACK and hitbox.has_overlapping_areas():
			#for area in hitbox.get_overlapping_areas():
				#if area.get_parent().has_method("speed_boost"):
					#velocity.x = direction * SPEED * 3
					#break
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0, SPEED/5)
	
	if state == States.ATTACK:
		hitbox.hit(damage)
		
	move_and_slide()

func take_damage(damage):
	health -= damage
	if health <= 0:
		get_tree().reload_current_scene()

func _on_animated_sprite_2d_animation_finished():
	hitbox.monitoring = false
	hurtbox.monitorable = true
	hurtbox.collision_layer = 2
	collision_layer = 1
	collision_mask = 1
	#$Player.collision
	if is_on_floor():
		state = States.IDLE
