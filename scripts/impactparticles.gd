extends Node3D

func _ready():
	var particles = $GPUParticles3D
	if particles:
		particles.emitting = true
		# Ждём окончания жизни частиц плюс небольшой запас
		await get_tree().create_timer(particles.lifetime * 1.5).timeout
	queue_free()
