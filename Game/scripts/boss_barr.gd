extends TextureProgressBar

var boss
@onready var progress_bar: TextureProgressBar = $TextureProgressBar

# Called when the node enters the scene tree for the first time.

# Called every frame. 'delta' is the elapsed time since the previous frame.

func _ready():
	visible = false
	
func change_health():
	value = boss.health

func asign_boss(b, under, over, progress):
	boss = b
	max_value = boss.health
	value = boss.health
	if progress != null:
		texture_progress = load(progress)
	if under != null:
		texture_under = load(under)
	if over != null:
		texture_over = load(over) 

func start_battle():
	visible = true

func end_boss():
	boss = null
	visible = false
