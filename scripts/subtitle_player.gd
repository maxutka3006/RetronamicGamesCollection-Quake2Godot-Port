extends Node

@export var audio_player: AudioStreamPlayer
@export var subtitle_label: RichTextLabel

# Оригинальный метод (без задержки)
func play_with_subtitle(stream: AudioStream) -> void:
	audio_player.stream = stream
	subtitle_label.visible = true

	if audio_player.finished.is_connected(_on_audio_finished):
		audio_player.finished.disconnect(_on_audio_finished)
	audio_player.finished.connect(_on_audio_finished)

	audio_player.play()

# Новый метод с задержкой
func play_subtitle_with_delay(stream: AudioStream, delay: float = 1.0) -> void:
	# Прячем текст до старта (если он был)
	subtitle_label.visible = false
	# Ожидаем указанное количество секунд
	await get_tree().create_timer(delay).timeout
	# Запускаем обычный метод
	play_with_subtitle(stream)

func _on_audio_finished() -> void:
	subtitle_label.visible = false

func stop() -> void:
	audio_player.stop()
	subtitle_label.visible = false
