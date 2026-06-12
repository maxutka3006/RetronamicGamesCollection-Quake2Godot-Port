extends Node

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_fullscreen"):
		_toggle_fullscreen()

func _toggle_fullscreen() -> void:
	var current_mode = DisplayServer.window_get_mode()
	
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		# Возвращаемся в оконный режим
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		# Переходим в полноэкранный режим
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
