extends Node3D

const uw1_begin = preload("res://assets/sounds/uw1_begin.ogg")

func _ready():
	$SubtitlePlayer.play_subtitle_with_delay(uw1_begin, 1.1)
