extends TextureProgressBar

var boss

# Called when the node enters the scene tree for the first time.
func _ready():
	boss = get_tree().get_current_scene().get_node("Boss")
	max_value = boss.health
	value = boss.health


# Called every frame. 'delta' is the elapsed time since the previous frame.
func change_health():
	value = boss.health
