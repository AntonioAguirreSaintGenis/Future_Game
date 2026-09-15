extends Area2D

var parent
var victim

# Called every frame. 'delta' is the elapsed time since the previous frame.
func hit(damage):
	if has_overlapping_areas():
		parent = get_parent()
		var victims = {}
		var overlapping_areas = get_overlapping_areas()
		for area in overlapping_areas:
			victim = area.get_parent()
			if victim.has_method("hitable"):
				if victim.hitable():
					if victim.has_method("take_damage") and victim != parent:
						if not victims.has(victim):
							victims[victim] = true
							victim.take_damage(damage)
							if parent.name == "Player":
								if get_parent().rage < 6:
									get_parent().rage += 1
				elif victim.name == "Player":
					pass
					if victim.mana < 2:
						victim.mana += 1
			#print(parent)
