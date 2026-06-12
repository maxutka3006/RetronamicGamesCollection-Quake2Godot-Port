extends Node3D

@export var impact_sounds: Array[AudioStream] = []   # заполните в инспекторе
@export var impact_volume_db: float = -5.0
@export var min_impact_speed: float = 0.3            # порог скорости для звука

var _has_played_impact: bool = false

func _ready():
	$LifetimeTimer.timeout.connect(_on_timeout)
	$Body.body_entered.connect(_on_body_entered)

func _on_body_entered(_body: Node):
	# Игнорируем столкновения с игроком (он исключён, но на всякий случай)
	if _has_played_impact:
		return
	# Проверяем скорость для реализма (слабые касания не звучат)
	if $Body.linear_velocity.length() < min_impact_speed:
		return

	_has_played_impact = true
	_play_impact_sound()

func _play_impact_sound():
	if impact_sounds.is_empty():
		return
	var snd = impact_sounds[randi() % impact_sounds.size()]
	$ImpactSound.stream = snd
	$ImpactSound.volume_db = impact_volume_db
	$ImpactSound.play()

func _on_timeout():
	queue_free()
