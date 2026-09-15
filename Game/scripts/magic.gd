extends Node2D

var animated_sprite1
var animated_sprite2
var player
var timer
var spell1
var spell2
var spell
var hitbox1
var hitbox2
var hitbox
var offset1
var offset2
var offset
var spell_cast = false

func _ready():
	spell1 = load("res://scenes/spells/laser.tscn").instantiate()
	spell2 = load("res://scenes/spells/laser+fire.tscn").instantiate()
	player = get_parent().get_node("Player")
	add_child(spell1)
	add_child(spell2)
	hitbox1 = spell1.get_node("Hitbox")
	hitbox2 = spell2.get_node("Hitbox")
	animated_sprite1 = spell1.get_node("AnimatedSprite2D")
	animated_sprite2 = spell2.get_node("AnimatedSprite2D")
	animated_sprite1.visible = false
	animated_sprite2.visible = false
	hitbox1.monitoring = false
	hitbox2.monitoring = false
	offset1 = animated_sprite1.offset.x
	offset2 = animated_sprite2.offset.x

func _process(_delta):
	if spell_cast:
		hitbox.hit(spell.get_meta("damage"))

func cast_spell(nb):
	if nb == 1:
		hitbox = hitbox1
		offset = offset1
		spell = spell1
		do_spell(animated_sprite1)
	else:
		hitbox = hitbox2
		spell = spell2
		offset = offset2
		do_spell(animated_sprite2)
		
func do_spell(animated_sprite):
	spell_cast = true
	if not player.animated_sprite.flip_h:
		animated_sprite.flip_h = false
		animated_sprite.offset.x = offset
		hitbox.scale.x = 1
	else:
		animated_sprite.flip_h = true
		animated_sprite.offset.x = -offset
		hitbox.scale.x = -1
	animated_sprite.visible = true
	hitbox.monitoring = true
	spell.position.y = player.position.y
	spell.position.x = player.position.x
	animated_sprite.play()
	timer = get_tree().create_timer(1.8)
	await timer.timeout
	animated_sprite.visible = false
	hitbox.monitoring = false
	spell_cast = false
