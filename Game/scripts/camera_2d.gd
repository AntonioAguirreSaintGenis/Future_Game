extends Camera2D

@onready var camera = $Camera2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if Input.is_action_just_pressed("turn off camera"):
		if enabled:
			enabled = false
			camera.global_position = get_parent().global_position
			camera.enabled = true
			
		else:
			camera.enabled = false
			enabled = true
	if Input.is_action_pressed("zoom_in"):
		camera.zoom += Vector2(0.01, 0.01)
	if Input.is_action_pressed("zoom_out"):
		camera.zoom -= Vector2(0.01, 0.01)
