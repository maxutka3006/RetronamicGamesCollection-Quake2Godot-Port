extends Control

func _ready() -> void:
	await get_tree().process_frame
	
	# Start loading a scene
	if GameState.next_scene != "":
		get_tree().change_scene_to_file(GameState.next_scene)
	else:
		push_error("Failed to load scene!")
