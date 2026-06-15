extends Control

# Scene paths
const LOADING_SCENE_PATH = "res://menu/loading_screen.tscn"
const GAME_SCENE_PATH = "res://levels/urbanwarfare1_metrolevel.tscn"
const MENUHELPCREDITS_SCENE_PATH = "res://menu/menu_helpcredits.tscn"
const TESTARENA_SCENE_PATH = "res://levels/testarena.tscn"

@onready var start_button: Button = $VBoxContainer/StartGame
@onready var helpcredits_button: Button = $VBoxContainer/HelpCredits
@onready var testarena_button: Button = $StartTestArena
@onready var quit_button: Button = $VBoxContainer/Quit


func _ready():
	# Grab focus for keyboard/gamepad navigation
	# start_button.grab_focus()

	# Connect button pressed sounds
	start_button.pressed.connect(_on_start_pressed)
	helpcredits_button.pressed.connect(_on_helpcredits_pressed)
	testarena_button.pressed.connect(_on_testarena_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	start_button.grab_focus()


func _on_start_pressed():
	GameState.next_scene = GAME_SCENE_PATH
	get_tree().change_scene_to_file(LOADING_SCENE_PATH)

func _on_helpcredits_pressed():
	if ResourceLoader.exists(MENUHELPCREDITS_SCENE_PATH):
		get_tree().change_scene_to_file(MENUHELPCREDITS_SCENE_PATH)
	else:
		push_error("Scene not found: " + MENUHELPCREDITS_SCENE_PATH)

func _on_testarena_pressed():
	GameState.next_scene = TESTARENA_SCENE_PATH
	get_tree().change_scene_to_file(LOADING_SCENE_PATH)

func _on_quit_pressed():
	# Quit: exit application
	get_tree().quit()
