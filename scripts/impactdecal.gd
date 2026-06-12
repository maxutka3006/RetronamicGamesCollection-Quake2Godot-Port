extends Node3D

func _ready():
	$LifetimeTimer.timeout.connect(queue_free)
	$LifetimeTimer.start()
