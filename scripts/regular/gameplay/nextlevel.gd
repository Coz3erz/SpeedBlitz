extends Sprite2D

func _on_jumppad_area_entered(area):
	if area.get_parent().name == "blitz":
		var player = area.get_parent()
		var current_level = int(get_tree().current_scene.name.replace("level", ""))
		var next_level = current_level + 1
		
		print("Level completed: ", current_level, " → Unlocking level ", next_level)
		
		# Unlock the next level
		LevelSave.unlock_level(next_level)
		
		# Fade out the player immediately
		var tween = create_tween()
		tween.tween_property(player, "modulate:a", 0.0, 0.2)
		
		# Load next level using SceneManager (which handles its own animations)
		SceneManager.change_scene(get_node("/root"), "res://scenes/levels/level" + str(next_level) + ".tscn")
