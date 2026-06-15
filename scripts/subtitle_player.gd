extends Node

@export var audio_player: AudioStreamPlayer
@export var subtitle_label: RichTextLabel

func play_with_subtitle(stream: AudioStream) -> void:
	audio_player.stream = stream
	subtitle_label.visible = true

	if audio_player.finished.is_connected(_on_audio_finished):
		audio_player.finished.disconnect(_on_audio_finished)
	audio_player.finished.connect(_on_audio_finished)

	audio_player.play()

func play_subtitle_with_delay(stream: AudioStream, delay: float = 1.0) -> void:
	subtitle_label.visible = false
	await get_tree().create_timer(delay).timeout
	play_with_subtitle(stream)

func _on_audio_finished() -> void:
	subtitle_label.visible = false

func stop() -> void:
	audio_player.stop()
	subtitle_label.visible = false
