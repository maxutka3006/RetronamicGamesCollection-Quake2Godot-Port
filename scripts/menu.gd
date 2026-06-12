extends Control

# Путь к сцене, которую нужно запустить (укажите свой)
const GAME_SCENE_PATH = "res://levels/urbanwarfare1_metrolevel.tscn"
const MENUHELPCREDITS_SCENE_PATH = "res://menu/menu_helpcredits.tscn"
const TESTARENA_SCENE_PATH = "res://levels/testarena.tscn"

@onready var start_button: Button = $VBoxContainer/StartGame
@onready var helpcredits_button: Button = $VBoxContainer/HelpCredits
@onready var testarena_button: Button = $StartTestArena
@onready var quit_button: Button = $VBoxContainer/Quit


func _ready():
	# Берём фокус на первой кнопке, чтобы курсор сразу активен
	# start_button.grab_focus()

	# Подключаем сигналы кнопок
	start_button.pressed.connect(_on_start_pressed)
	helpcredits_button.pressed.connect(_on_helpcredits_pressed)
	testarena_button.pressed.connect(_on_testarena_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	$VBoxContainer/StartGame.grab_focus()


func _on_start_pressed():
	GameState.next_scene = GAME_SCENE_PATH
	get_tree().change_scene_to_file("res://menu/loading_screen.tscn")

func _on_helpcredits_pressed():
	if ResourceLoader.exists(MENUHELPCREDITS_SCENE_PATH):
		get_tree().change_scene_to_file(MENUHELPCREDITS_SCENE_PATH)
	else:
		push_error("Сцена не найдена: " + MENUHELPCREDITS_SCENE_PATH)

func _on_testarena_pressed():
	GameState.next_scene = TESTARENA_SCENE_PATH
	get_tree().change_scene_to_file("res://menu/loading_screen.tscn")

func _on_quit_pressed():
	# Выход из игры
	get_tree().quit()
