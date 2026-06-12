extends Node3D
class_name Weapon

# -------------------------------------------------- Экспорт: стрельба
@export var fire_rate: float = 0.15
@export var damage: float = 10.0

@export var max_magazine: int = 10
@export var reserve_ammo: int = 20
@export var infinite_ammo: bool = false

@export var automatic: bool = false
@export var reload_time: float = 1.5

@export var muzzle_flash_scene: PackedScene
@export var casing_scene: PackedScene
@export var impact_particles_scene: PackedScene
@export var impact_decal_scene: PackedScene

# -------------------------------------------------- Экспорт: раскачка (bobbing)
@export_group("Weapon Bob")
@export var bob_enabled: bool = true
@export var bob_frequency: float = 2.0
@export var bob_amplitude_vertical: float = 0.03
@export var bob_amplitude_horizontal: float = 0.05
@export var bob_rotation_amplitude: float = 0.02
@export var bob_smoothing: float = 10.0

# -------------------------------------------------- Экспорт: вспышка света
@export_group("Muzzle Flash Light")
@export var muzzle_light_enabled: bool = true
@export var muzzle_light_energy: float = 8.0
@export var muzzle_light_duration: float = 0.05

# -------------------------------------------------- Экспорт: гильзы
@export_group("Casing")
@export var casing_eject_velocity: float = 2.0
@export var casing_eject_direction: Vector3 = Vector3(1.0, 1.0, 0.0)
@export var casing_spin_min: float = 5.0
@export var casing_spin_max: float = 15.0

# -------------------------------------------------- Экспорт: звук пустого магазина
@export_group("No Ammo")
@export var no_ammo_sound: AudioStream

# -------------------------------------------------- Экспорт: звуки выстрела (рандомизация)
@export_group("Shoot Sounds")
@export var shoot_sounds: Array[AudioStream] = []
@export var shoot_volume_db: float = 0.0

# -------------------------------------------------- Экспорт: звуки перезарядки (несколько этапов)
@export_group("Reload Sounds")
@export var reload_start_sounds: Array[AudioStream] = []
@export var reload_start_volume_db: float = 0.0
@export var reload_end_sounds: Array[AudioStream] = []
@export var reload_end_volume_db: float = 0.0
@export var reload_end_delay: float = 0.6

# -------------------------------------------------- Экспорт: звук попадания в поверхность
@export_group("Impact")
@export var impact_sounds: Array[AudioStream] = []
@export var impact_volume_db: float = -5.0
@export var impact_sound_chance: float = 1.0
@export var impact_particle_colors: Array[Color] = []

# -------------------------------------------------- Экспорт: продвинутые настройки
@export_group("Advanced")
@export var block_switch_during_attack: bool = true
@export var block_switch_on_reload: bool = true
@export var block_reload_during_fire: bool = true

# -------------------------------------------------- Экспорт: ссылки
@export_group("References")
@export var player: QuakePlayer
@export var camera: Camera3D
@export var model: Node3D

# -------------------------------------------------- Узлы (опциональные)
@onready var anim_player: AnimationPlayer = $AnimationPlayer
var muzzle_light: OmniLight3D = null
var casing_point: Marker3D = null
var no_ammo_player: AudioStreamPlayer3D = null
var shoot_audio: AudioStreamPlayer3D = null
var reload_start_audio: AudioStreamPlayer3D = null
var reload_end_audio: AudioStreamPlayer3D = null
var _impact_audio: AudioStreamPlayer3D = null

# -------------------------------------------------- Состояние
var current_magazine: int = max_magazine
var _fire_timer: float = 0.0
var _trigger_pressed: bool = false
var _is_reloading: bool = false
var _reload_timer: float = 0.0
var _reload_second_sound_played: bool = false

var _model_default_pos: Vector3
var _model_default_rot: Vector3
var _bob_phase: float = 0.0
var _muzzle_light_timer: float = 0.0

# Список названий анимаций, после которых нужно вернуться в Idle
var attack_anim_names: Array[String] = ["Shoot"]

func _ready():
	current_magazine = max_magazine

	# Опциональные узлы – не вызывают ошибок, если отсутствуют
	muzzle_light = get_node_or_null("MuzzleLight") as OmniLight3D
	casing_point = get_node_or_null("CasingEjectPoint") as Marker3D
	no_ammo_player = get_node_or_null("NoAmmoAudio")
	if not no_ammo_player:
		no_ammo_player = AudioStreamPlayer3D.new()
		no_ammo_player.name = "NoAmmoAudio"
		add_child(no_ammo_player)

	shoot_audio = get_node_or_null("ShootAudio") as AudioStreamPlayer3D
	if not shoot_audio:
		shoot_audio = AudioStreamPlayer3D.new()
		shoot_audio.name = "ShootAudio"
		add_child(shoot_audio)

	reload_start_audio = get_node_or_null("ReloadStartAudio") as AudioStreamPlayer3D
	if not reload_start_audio:
		reload_start_audio = AudioStreamPlayer3D.new()
		reload_start_audio.name = "ReloadStartAudio"
		add_child(reload_start_audio)

	reload_end_audio = get_node_or_null("ReloadEndAudio") as AudioStreamPlayer3D
	if not reload_end_audio:
		reload_end_audio = AudioStreamPlayer3D.new()
		reload_end_audio.name = "ReloadEndAudio"
		add_child(reload_end_audio)

	if anim_player:
		if anim_player.has_animation("Idle"):
			anim_player.play("Idle")
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)
	else:
		push_warning("В оружии отсутствует AnimationPlayer!")

	if model:
		_model_default_pos = model.position
		_model_default_rot = model.rotation
	else:
		push_warning("Модель оружия не назначена! Bobbing не будет работать.")

	if muzzle_light:
		muzzle_light.light_energy = 0.0

	# Автоопределение камеры, если не задана вручную
	if not camera:
		var node = get_parent()
		while node:
			if node is Camera3D:
				camera = node
				break
			node = node.get_parent()
		if not camera:
			push_warning("Камера не назначена и не найдена автоматически. Стрельба не будет работать.")

func _process(delta: float) -> void:
	if _is_reloading:
		_reload_timer -= delta
		if not _reload_second_sound_played and (reload_time - _reload_timer) >= reload_end_delay:
			_play_random_sound(reload_end_sounds, reload_end_audio, reload_end_volume_db)
			_reload_second_sound_played = true
		if _reload_timer <= 0.0:
			_finish_reload()

	_update_bobbing(delta)
	_update_muzzle_light(delta)

func _physics_process(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta

# ---------- Управление ----------
func trigger_pressed():
	_trigger_pressed = true
	if _is_reloading:
		return
	if automatic:
		try_fire()
	elif _fire_timer <= 0.0 and current_magazine > 0:
		try_fire()

func trigger_released():
	_trigger_pressed = false

func reload():
	if block_reload_during_fire and anim_player and anim_player.is_playing() and anim_player.current_animation == "Shoot":
		return

	if _is_reloading or current_magazine == max_magazine:
		return
	if not infinite_ammo and reserve_ammo <= 0:
		return

	_is_reloading = true
	_reload_timer = reload_time
	_reload_second_sound_played = false

	if anim_player and anim_player.has_animation("Reload"):
		anim_player.stop()
		anim_player.play("Reload")

	_play_random_sound(reload_start_sounds, reload_start_audio, reload_start_volume_db)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name in attack_anim_names:
		if anim_player and anim_player.has_animation("Idle"):
			anim_player.play("Idle")

func _finish_reload():
	var needed = max_magazine - current_magazine
	if infinite_ammo:
		current_magazine = max_magazine
	else:
		var transfer = min(needed, reserve_ammo)
		current_magazine += transfer
		reserve_ammo -= transfer

	_is_reloading = false
	_reload_timer = 0.0
	_reload_second_sound_played = false

	if anim_player and anim_player.has_animation("Idle"):
		anim_player.play("Idle")

func try_fire() -> bool:
	if _is_reloading or _fire_timer > 0.0:
		return false

	if not infinite_ammo and current_magazine <= 0:
		_play_no_ammo_sound()
		return false

	if not infinite_ammo:
		current_magazine -= 1
	_fire_timer = fire_rate

	if anim_player and anim_player.has_animation("Shoot"):
		anim_player.stop()
		anim_player.play("Shoot")

	_play_random_sound(shoot_sounds, shoot_audio, shoot_volume_db)

	_trigger_muzzle_light()
	_eject_casing()
	_fire_raycast()
	return true

func _play_no_ammo_sound():
	if no_ammo_sound and no_ammo_player:
		no_ammo_player.stream = no_ammo_sound
		no_ammo_player.play()

# ---------- Вспышка света ----------
func _trigger_muzzle_light():
	if muzzle_light_enabled and muzzle_light:
		muzzle_light.light_energy = muzzle_light_energy
		_muzzle_light_timer = muzzle_light_duration

func _update_muzzle_light(delta: float):
	if not muzzle_light or not muzzle_light_enabled:
		return
	if _muzzle_light_timer > 0.0:
		_muzzle_light_timer -= delta
		if _muzzle_light_timer <= 0.0:
			muzzle_light.light_energy = 0.0

# ---------- Выброс гильзы ----------
func _eject_casing():
	if not casing_scene or not casing_point:
		return

	var casing = casing_scene.instantiate()
	get_tree().root.add_child(casing)
	casing.global_position = casing_point.global_position

	var dir = global_transform.basis * casing_eject_direction.normalized()
	var eject_velocity = dir * casing_eject_velocity

	var body = casing.get_node_or_null("Body")
	if body and body is RigidBody3D:
		body.linear_velocity = eject_velocity
		body.angular_velocity = Vector3(
			randf_range(casing_spin_min, casing_spin_max),
			randf_range(casing_spin_min, casing_spin_max),
			randf_range(casing_spin_min, casing_spin_max)
		)
		if player:
			body.add_collision_exception_with(player)

# ---------- Стрельба ----------
func _fire_raycast():
	var cam = camera
	if not cam:
		push_warning("Камера не назначена в оружии!")
		return

	var space_state = get_world_3d().direct_space_state
	var ray_origin = cam.project_ray_origin(get_viewport_center())
	var ray_dir = cam.project_ray_normal(get_viewport_center())

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 1000.0)
	query.collision_mask = 1
	query.exclude = [player] if player else []

	var result = space_state.intersect_ray(query)

	if result:
		var collider = result.collider
		if collider.has_method("damage"):
			collider.damage(damage)
		else:
			_play_impact_sound(result.position, result.normal)
			_spawn_impact_particles(result.position, result.normal)
			_spawn_impact_decal(result.position, result.normal)
		_spawn_muzzle_flash(ray_origin, ray_dir)
	else:
		_spawn_muzzle_flash(ray_origin, ray_dir)

func _play_impact_sound(hit_point: Vector3, _hit_normal: Vector3):
	if impact_sounds.is_empty():
		return
	if randf() > impact_sound_chance:
		return

	if not _impact_audio:
		_impact_audio = AudioStreamPlayer3D.new()
		_impact_audio.name = "ImpactAudio"
		add_child(_impact_audio)
	_impact_audio.stream = impact_sounds[randi() % impact_sounds.size()]
	_impact_audio.volume_db = impact_volume_db
	_impact_audio.global_position = hit_point
	_impact_audio.play()

func _spawn_impact_particles(hit_point: Vector3, hit_normal: Vector3):
	if not impact_particles_scene:
		return
	var particles = impact_particles_scene.instantiate()
	get_tree().root.add_child(particles)
	particles.global_position = hit_point + hit_normal * 0.05

	# Безопасная ориентация
	var up = Vector3.UP
	if abs(hit_normal.dot(Vector3.UP)) > 0.99:
		up = Vector3.RIGHT
	particles.look_at(hit_point - hit_normal, up)

	if not impact_particle_colors.is_empty():
		var color = impact_particle_colors[randi() % impact_particle_colors.size()]
		var gpup = particles.get_node_or_null("GPUParticles3D")
		if gpup and gpup.draw_pass_1:
			var mesh = gpup.draw_pass_1
			var mat = mesh.material.duplicate() if mesh.material else StandardMaterial3D.new()
			mat.albedo_color = color
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mesh.material = mat

func _spawn_impact_decal(hit_point: Vector3, hit_normal: Vector3):
	if not impact_decal_scene:
		return
	var decal = impact_decal_scene.instantiate()
	get_tree().root.add_child(decal)
	decal.global_position = hit_point + hit_normal * 0.02

	var up = Vector3.UP
	if abs(hit_normal.dot(Vector3.UP)) > 0.99:
		up = Vector3.RIGHT
	decal.look_at(hit_point - hit_normal, up)

func get_viewport_center() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5

func _spawn_muzzle_flash(origin: Vector3, dir: Vector3):
	if muzzle_flash_scene:
		var flash = muzzle_flash_scene.instantiate()
		get_tree().root.add_child(flash)
		flash.global_position = origin + dir * 0.5
		flash.look_at(origin + dir, Vector3.UP)

# ---------- Bobbing ----------
func _update_bobbing(delta: float) -> void:
	if not bob_enabled or not model or not player:
		return

	var on_ground = player.is_on_floor()
	var speed = player._current_h_speed

	if on_ground and speed > player.headbob_min_speed:
		var freq = bob_frequency * (speed / player.move_speed)
		_bob_phase += freq * delta * TAU
		_bob_phase = fmod(_bob_phase, TAU)

		var vert = sin(_bob_phase) * bob_amplitude_vertical
		var horiz = cos(_bob_phase) * bob_amplitude_horizontal
		var roll = sin(_bob_phase) * bob_rotation_amplitude

		var target_pos = _model_default_pos + Vector3(horiz, vert, 0.0)
		var target_rot = _model_default_rot + Vector3(0.0, 0.0, roll)

		model.position = model.position.lerp(target_pos, bob_smoothing * delta)
		model.rotation = model.rotation.lerp(target_rot, bob_smoothing * delta)
	else:
		_bob_phase = 0.0
		model.position = model.position.lerp(_model_default_pos, bob_smoothing * delta)
		model.rotation = model.rotation.lerp(_model_default_rot, bob_smoothing * delta)

func _play_random_sound(sounds: Array, audio_player: AudioStreamPlayer3D, volume_db: float) -> void:
	if sounds.is_empty() or not audio_player:
		return
	audio_player.stream = sounds[randi() % sounds.size()]
	audio_player.volume_db = volume_db
	audio_player.play()

func shows_ammo() -> bool:
	return max_magazine > 0

func is_attacking() -> bool:
	return anim_player and anim_player.is_playing() and anim_player.current_animation in attack_anim_names

func is_reloading() -> bool:
	return _is_reloading
