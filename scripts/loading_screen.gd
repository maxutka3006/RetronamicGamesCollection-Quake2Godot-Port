extends Control

func _ready() -> void:
	# Даём интерфейсу один кадр, чтобы точно отрисоваться
	await get_tree().process_frame
	
	# Переходим на целевую сцену (синхронно, но экран уже виден)
	if GameState.next_scene != "":
		get_tree().change_scene_to_file(GameState.next_scene)
	else:
		push_error("Не задана сцена для загрузки!")
