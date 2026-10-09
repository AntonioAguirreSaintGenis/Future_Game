extends Node2D

var player
var timer
var spell_normal
var spell_big
var spell_cast = false
var spell

func _ready():
	player = get_parent().get_node("Player")
	spell_normal = load(player.spell_normal)
	spell_big = load(player.spell_big)

func cast_spell(select):
	if select == false:
		if spell_cast == false:
			spell_cast = true
			spell = spell_normal.instantiate()
			if player.spell_normal != null and player.mana >= spell.cost:
				player.mana -= spell.cost
				do_spell(spell)
				spell_cast = false
			else:
				spell.queue_free()
				spell_cast = false
	else:
		if spell_cast == false:
			spell_cast = true
			spell = spell_big.instantiate()
			if player.spell_big != null and player.mana >= spell.cost:
				player.mana -= spell.cost
				do_spell(spell)
				spell_cast = false
			else:
				spell.queue_free()
				spell_cast = false
		
func do_spell(spell):
	add_child(spell)
	spell.start_spell(player)
	"""spell_cast = true
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
	spell_cast = false"""
