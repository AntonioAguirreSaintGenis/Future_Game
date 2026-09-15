extends CanvasLayer

@onready var healthbar = $Healthbar
@onready var manabar = $Manabar
@onready var ragebar = $Ragebar

var player

func _ready():
	player = get_tree().get_current_scene().get_node("Player")
	healthbar.max_value = player.health
	healthbar.value = player.health
	manabar.max_value = 2
	manabar.value = player.mana
	ragebar.max_value = 6
	ragebar.value = player.rage

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	healthbar.value = player.health
	manabar.value = player.mana
	ragebar.value = player.rage
