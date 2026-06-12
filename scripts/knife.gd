extends Weapon
class_name Knife

@export var knife_damage: float = 50.0
@export var knife_range: float = 2.0

@export var attack_animations: Array[String] = ["Shoot"]

func _ready():
	super._ready()
	infinite_ammo = true
	automatic = false
	fire_rate = 0.4
	bob_enabled = true
	attack_anim_names = attack_animations

func try_fire() -> bool:
	if _is_reloading or _fire_timer > 0.0:
		return false

	if anim_player and not attack_animations.is_empty():
		anim_player.stop()
		var anim = attack_animations[randi() % attack_animations.size()]
		if anim_player.has_animation(anim):
			anim_player.play(anim)
		else:
			if anim_player.has_animation("Shoot"):
				anim_player.play("Shoot")
			else:
				push_warning("Нет анимации для атаки ножа!")

	_fire_timer = fire_rate
	return true

func _deal_damage():
	var cam = camera
	if not cam:
		return

	var space_state = get_world_3d().direct_space_state
	var ray_origin = cam.project_ray_origin(get_viewport_center())
	var ray_dir = cam.project_ray_normal(get_viewport_center())

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * knife_range)
	query.collision_mask = 1
	query.exclude = [player] if player else []   # <-- исключаем игрока

	var result = space_state.intersect_ray(query)

	if result:
		var collider = result.collider
		if collider.has_method("damage"):
			collider.damage(knife_damage)
		else:
			_play_impact_sound(result.position, result.normal)
			_spawn_impact_particles(result.position, result.normal)
			_spawn_impact_decal(result.position, result.normal)

func reload():
	pass   # нож не перезаряжается

func shows_ammo() -> bool:
	return false
