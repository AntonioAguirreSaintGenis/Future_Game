extends Area2D

func _on_body_entered(body):
	if body == get_parent().target and get_parent().agro == false:
		get_parent().state = get_parent().start_state
		get_parent().agro = true # Replace with function body.
		#queue_free()
