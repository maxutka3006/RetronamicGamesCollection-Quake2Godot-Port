extends Control

const MENU_SCENE_PATH = "res://menu/menu.tscn"

@onready var back_button: Button = $BackButt


func _ready():
	back_button.pressed.connect(_on_back_pressed)
	$BackButt.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if ResourceLoader.exists(MENU_SCENE_PATH):
			get_tree().change_scene_to_file(MENU_SCENE_PATH)
		else:
			push_error("Сцена не найдена: " + MENU_SCENE_PATH)

func _on_back_pressed():
	if ResourceLoader.exists(MENU_SCENE_PATH):
		get_tree().change_scene_to_file(MENU_SCENE_PATH)
	else:
		push_error("Сцена не найдена: " + MENU_SCENE_PATH)
