extends CharacterBody3D
class_name QuakePlayer

const MENU_SCENE_PATH = "res://menu/menu.tscn"

# -------------------------------------------------- Мышь
@export_group("Mouse")
@export var mouse_sensitivity: float = 0.0025

# -------------------------------------------------- Геймпад
@export_group("Gamepad")
@export var gamepad_look_sensitivity: float = 3.0
@export var invert_gamepad_x: bool = false
@export var invert_gamepad_y: bool = false

# -------------------------------------------------- Земля
@export_group("Ground Movement")
@export var move_speed: float = 10.0
@export var ground_accel: float = 10.0
@export var ground_friction: float = 6.0

# -------------------------------------------------- Воздух
@export_group("Air Movement")
@export var air_speed_cap: float = 1.0
@export var air_accel: float = 70.0
@export var max_air_speed: float = 30.0

# -------------------------------------------------- Прыжки / Гравитация
@export_group("Jump / Gravity")
@export var gravity: float = 24.0
@export var jump_velocity: float = 7.0
@export var coyote_time: float = 0.12

# -------------------------------------------------- Ступеньки
@export_group("Stair Stepping")
@export var step_height: float = 0.45
@export var step_down_extra: float = 0.12
@export var step_forward_probe: float = 1.05

# -------------------------------------------------- Пол
@export_group("Floor")
@export var floor_snap: float = 0.35
@export var floor_angle_degrees: float = 46.0
@export var collision_safe_margin: float = 0.02

# -------------------------------------------------- Headbob
@export_group("Headbob")
@export var headbob_enabled: bool = true
@export var headbob_frequency: float = 2.0
@export var headbob_amp_vertical: float = 0.06
@export var headbob_amp_horizontal: float = 0.04
@export var headbob_min_speed: float = 0.5

# -------------------------------------------------- Sway
@export_group("Sway")
@export var sway_enabled: bool = true
@export var sway_amount: float = 0.15
@export var sway_smoothing: float = 8.0

# -------------------------------------------------- Звуки шагов
@export_group("Footsteps")
@export var footstep_sounds: Array[AudioStream] = []
@export var footstep_volume_db: float = -5.0
@export var footstep_distance: float = 2.5
@export var footstep_distance_variance: float = 0.2
@export var footstep_min_speed: float = 0.5

# -------------------------------------------------- Звук приземления
@export_group("Landing")
@export var landing_sounds: Array[AudioStream] = []
@export var landing_volume_db: float = -3.0
@export var landing_min_speed: float = 1.5

# -------------------------------------------------- Наклон камеры при стрейфе
@export_group("Camera Roll")
@export var camera_roll_enabled: bool = true
@export var camera_roll_max_angle_degrees: float = 2.0
@export var camera_roll_speed: float = 12.0

# -------------------------------------------------- Noclip
@export_group("Noclip")
@export var noclip_speed: float = 15.0

# -------------------------------------------------- Оружие: слоты и стартовое
@export_group("Weapon Slots")
@export var weapon_slot_names: Array[String] = []
@export var starting_weapon_name: String = "Pistol"

# -------------------------------------------------- Узлы
@onready var head: Node3D = $Head
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio
@onready var landing_audio: AudioStreamPlayer3D = $LandingAudio

# -------------------------------------------------- Внутренние переменные
var _wish_dir: Vector3 = Vector3.ZERO
var _was_on_floor: bool = false
var _snap_to_floor_after_move: bool = false
var _coyote_left: float = 0.0

var _head_default_pos: Vector3
var _headbob_phase: float = 0.0
var _current_h_speed: float = 0.0
var _sway_offset: Vector2 = Vector2.ZERO
var _mouse_delta_this_frame: Vector2 = Vector2.ZERO

var _pitch: float = 0.0
var _roll: float = 0.0

var _footstep_travel: float = 0.0
var _next_footstep_distance: float = 2.5

var noclip_enabled: bool = false
var _was_shooting: bool = false

# --- Система оружия ---
var weapons: Array[Weapon] = []
var active_weapon_index: int = -1

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	floor_snap_length = floor_snap
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(floor_angle_degrees)
	safe_margin = collision_safe_margin
	max_slides = 6

	_head_default_pos = head.position
	_next_footstep_distance = footstep_distance + randf_range(-footstep_distance_variance, footstep_distance_variance)

	if not footstep_audio:
		footstep_audio = AudioStreamPlayer3D.new()
		footstep_audio.name = "FootstepAudio"
		add_child(footstep_audio)
	if not landing_audio:
		landing_audio = AudioStreamPlayer3D.new()
		landing_audio.name = "LandingAudio"
		add_child(landing_audio)

	_find_weapons()

	# Активируем стартовое оружие
	active_weapon_index = -1
	if not starting_weapon_name.is_empty():
		_set_active_weapon_by_name(starting_weapon_name)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
		_mouse_delta_this_frame += event.relative

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("force_quit"):
		get_tree().quit()

	if event.is_action_pressed("back_to_menu"):
		if ResourceLoader.exists(MENU_SCENE_PATH):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file(MENU_SCENE_PATH)
		else:
			push_error("Сцена не найдена: " + MENU_SCENE_PATH)

	if event.is_action_pressed("noclip"):
		noclip_enabled = !noclip_enabled
		if noclip_enabled:
			set_collision_layer_value(1, false)
			set_collision_mask_value(1, false)
			velocity = Vector3.ZERO
		else:
			set_collision_layer_value(1, true)
			set_collision_mask_value(1, true)

	# Цифры 1-9: выбор оружия по имени из weapon_slot_names
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.keycode
		if key >= KEY_1 and key <= KEY_9:
			var slot = key - KEY_1
			if slot < weapon_slot_names.size():
				var target_name = weapon_slot_names[slot]
				if not target_name.is_empty():
					_set_active_weapon_by_name(target_name)

	# Колесо мыши
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_weapon(1)

	# Бамперы геймпада
	if event.is_action_pressed("weapon_next"):
		_cycle_weapon(1)
	if event.is_action_pressed("weapon_prev"):
		_cycle_weapon(-1)

func _physics_process(delta: float) -> void:
	if noclip_enabled:
		_noclip_move(delta)
		return

	var was_on_floor_before = is_on_floor()
	var prev_vertical_speed = velocity.y

	_was_on_floor = was_on_floor_before
	_update_wish_dir()

	if _was_on_floor:
		_coyote_left = coyote_time
	else:
		_coyote_left = maxf(_coyote_left - delta, 0.0)

	var can_jump: bool = _was_on_floor or _coyote_left > 0.0
	var jumped_this_frame: bool = false

	if Input.is_action_just_pressed("jump") and can_jump:
		velocity.y = jump_velocity
		jumped_this_frame = true
		_coyote_left = 0.0
		_snap_to_floor_after_move = false
	else:
		_snap_to_floor_after_move = _was_on_floor

	if not _was_on_floor and not jumped_this_frame:
		velocity.y -= gravity * delta

	if _was_on_floor and not jumped_this_frame:
		_ground_move(delta)
	else:
		_air_move(delta)

	_move_with_stair_stepping(delta)

	if not was_on_floor_before and is_on_floor():
		if abs(prev_vertical_speed) >= landing_min_speed:
			_play_landing_sound()

	_current_h_speed = Vector2(velocity.x, velocity.z).length()

	if _was_on_floor and _current_h_speed > footstep_min_speed:
		_footstep_travel += _current_h_speed * delta
		while _footstep_travel >= _next_footstep_distance:
			_play_footstep()
			_footstep_travel -= _next_footstep_distance
			_next_footstep_distance = footstep_distance + randf_range(-footstep_distance_variance, footstep_distance_variance)
	else:
		_footstep_travel = 0.0

func _process(delta: float) -> void:
	_update_head_rotation()
	_update_headbob(delta)
	_update_sway(delta)
	_update_camera_roll(delta)
	_handle_gamepad_look(delta)

	_mouse_delta_this_frame = Vector2.ZERO
	_process_weapon_input()

# -------------------------------------------------- Noclip
func _noclip_move(delta: float) -> void:
	var forward = -global_transform.basis.z
	var right = global_transform.basis.x
	var up = Vector3.UP

	var move_dir = Vector3.ZERO
	move_dir += forward * Input.get_axis("move_back", "move_forward")
	move_dir += right * Input.get_axis("move_left", "move_right")

	if Input.is_action_pressed("jump"):
		move_dir += up
	if Input.is_action_pressed("move_down"):
		move_dir -= up

	if move_dir.length() > 0.0:
		move_dir = move_dir.normalized()

	global_position += move_dir * noclip_speed * delta

# -------------------------------------------------- Оружие: поиск, переключение, ввод
func _find_weapons() -> void:
	weapons.clear()
	for child in find_children("*", "Weapon", true, false):
		weapons.append(child)

	if weapons.size() > 0:
		for w in weapons:
			w.visible = false
	else:
		push_warning("В сцене игрока не найдено ни одного оружия!")

func _set_active_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == active_weapon_index:
		return

	# Блокировка при перезарядке
	if active_weapon_index >= 0 and active_weapon_index < weapons.size():
		var w = weapons[active_weapon_index]
		if w.block_switch_on_reload and w.is_reloading():
			return

	# Блокировка при атаке
	if active_weapon_index >= 0 and active_weapon_index < weapons.size():
		var w = weapons[active_weapon_index]
		if w.block_switch_during_attack and w.is_attacking():
			return

	if active_weapon_index >= 0 and active_weapon_index < weapons.size():
		weapons[active_weapon_index].visible = false
	active_weapon_index = index
	weapons[active_weapon_index].visible = true
	_update_hud_weapon()

func _cycle_weapon(direction: int) -> void:
	if weapons.is_empty(): return
	var new_idx = active_weapon_index + direction
	if new_idx < 0: new_idx = weapons.size() - 1
	elif new_idx >= weapons.size(): new_idx = 0
	_set_active_weapon(new_idx)

func _set_active_weapon_by_name(weapon_name: String) -> void:
	for i in range(weapons.size()):
		if weapons[i].name == weapon_name:
			_set_active_weapon(i)
			break

func _process_weapon_input() -> void:
	if weapons.is_empty() or active_weapon_index >= weapons.size():
		return
	var w = weapons[active_weapon_index]

	var shoot_pressed = Input.is_action_pressed("shoot") or Input.get_action_strength("shoot_axis") > 0.5
	var shoot_just = Input.is_action_just_pressed("shoot") or (Input.get_action_strength("shoot_axis") > 0.5 and not _was_shooting)
	var shoot_released = Input.is_action_just_released("shoot") or (Input.get_action_strength("shoot_axis") < 0.2 and _was_shooting)

	if shoot_just:
		w.trigger_pressed()
	if shoot_pressed:
		w.trigger_pressed()
	if shoot_released:
		w.trigger_released()
	_was_shooting = shoot_pressed

	if Input.is_action_just_pressed("reload"):
		w.reload()

func _update_hud_weapon() -> void:
	var hud = get_node_or_null("HUD")
	if hud and hud.has_method("set_weapon") and active_weapon_index >= 0:
		hud.set_weapon(weapons[active_weapon_index])

func add_weapon(weapon_name: String, ammo_amount: int = 0) -> bool:
	var weapon_node = find_child(weapon_name, false, false)
	if not weapon_node or not weapon_node is Weapon:
		return false

	var weapon: Weapon = weapon_node
	if weapons.has(weapon):
		weapon.reserve_ammo += ammo_amount
		return true

	weapons.append(weapon)
	weapon.visible = false
	weapon.reserve_ammo = max(weapon.reserve_ammo, ammo_amount)
	_set_active_weapon(weapons.size() - 1)
	return true

# -------------------------------------------------- Камера
func _update_head_rotation() -> void:
	var head_basis = Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.FORWARD, _roll)
	head.transform.basis = head_basis

func _update_headbob(delta: float) -> void:
	if not headbob_enabled:
		return

	var on_ground = is_on_floor()
	var speed = _current_h_speed

	if on_ground and speed > headbob_min_speed:
		var freq = headbob_frequency * (speed / move_speed)
		_headbob_phase += freq * delta * TAU
		_headbob_phase = fmod(_headbob_phase, TAU)

		var vert = sin(_headbob_phase) * headbob_amp_vertical
		var horiz = cos(_headbob_phase) * headbob_amp_horizontal
		var bob_offset = Vector3(horiz, vert, 0.0)
		head.position = _head_default_pos + bob_offset + Vector3(_sway_offset.x, _sway_offset.y, 0.0)
	else:
		_headbob_phase = 0.0
		head.position = head.position.lerp(_head_default_pos + Vector3(_sway_offset.x, _sway_offset.y, 0.0), 10.0 * delta)

func _update_sway(delta: float) -> void:
	if not sway_enabled:
		_sway_offset = Vector2.ZERO
		return

	var target_x = -_mouse_delta_this_frame.x * sway_amount
	var target_y = -_mouse_delta_this_frame.y * sway_amount

	_sway_offset.x = lerp(_sway_offset.x, target_x, sway_smoothing * delta)
	_sway_offset.y = lerp(_sway_offset.y, target_y, sway_smoothing * delta)

	if not headbob_enabled:
		head.position = _head_default_pos + Vector3(_sway_offset.x, _sway_offset.y, 0.0)

func _update_camera_roll(delta: float) -> void:
	if not camera_roll_enabled:
		_roll = 0.0
		return

	var strafe = Input.get_axis("move_left", "move_right")
	var max_roll = deg_to_rad(camera_roll_max_angle_degrees)
	var target_roll = strafe * max_roll

	_roll = lerp_angle(_roll, target_roll, camera_roll_speed * delta)

func _handle_gamepad_look(delta: float) -> void:
	var look_input = Input.get_vector("look_right", "look_left", "look_down", "look_up")
	if look_input.length_squared() < 0.01:
		return

	var x_dir = -1.0 if invert_gamepad_x else 1.0
	var y_dir = -1.0 if invert_gamepad_y else 1.0

	rotate_y(x_dir * look_input.x * gamepad_look_sensitivity * delta)
	_pitch += y_dir * look_input.y * gamepad_look_sensitivity * delta
	_pitch = clampf(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))

# -------------------------------------------------- Звуки
func _play_footstep() -> void:
	if footstep_sounds.is_empty():
		return
	var snd = footstep_sounds[randi() % footstep_sounds.size()]
	footstep_audio.stream = snd
	footstep_audio.volume_db = footstep_volume_db
	footstep_audio.play()

func _play_landing_sound() -> void:
	if landing_sounds.is_empty():
		return
	var snd = landing_sounds[randi() % landing_sounds.size()]
	landing_audio.stream = snd
	landing_audio.volume_db = landing_volume_db
	landing_audio.play()

# ---------- Движение (Quake) ----------
func _update_wish_dir() -> void:
	var input_dir: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	var local_dir: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)
	_wish_dir = (global_transform.basis * local_dir).normalized()

func _ground_move(delta: float) -> void:
	var hvel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)

	var speed: float = hvel.length()
	if speed > 0.0:
		var drop: float = speed * ground_friction * delta
		hvel *= maxf(speed - drop, 0.0) / speed

	hvel = _accelerate(hvel, _wish_dir, move_speed, ground_accel, delta)

	velocity.x = hvel.x
	velocity.z = hvel.z

func _air_move(delta: float) -> void:
	var hvel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	hvel = _accelerate(hvel, _wish_dir, air_speed_cap, air_accel, delta)

	var speed: float = hvel.length()
	if speed > max_air_speed:
		hvel *= max_air_speed / speed

	velocity.x = hvel.x
	velocity.z = hvel.z

func _accelerate(hvel: Vector3, wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> Vector3:
	if wish_dir.is_zero_approx():
		return hvel

	var current_speed: float = hvel.dot(wish_dir)
	var add_speed: float = wish_speed - current_speed

	if add_speed <= 0.0:
		return hvel

	var accel_speed: float = minf(accel * wish_speed * delta, add_speed)
	return hvel + wish_dir * accel_speed

# ---------- Система ступенек ----------
func _move_with_stair_stepping(delta: float) -> void:
	var horizontal_vel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var h_motion: Vector3 = horizontal_vel * delta

	var can_step_up: bool = (
		_was_on_floor
		and velocity.y <= 0.0
		and h_motion.length_squared() > 0.000001
	)

	if can_step_up:
		var forward_test: Dictionary = _test_motion(global_transform, h_motion)
		if _result_collided(forward_test):
			if _try_step_up(h_motion):
				return

	move_and_slide()

	if _snap_to_floor_after_move and not is_on_floor() and velocity.y <= 0.0:
		_try_step_down()

func _try_step_up(h_motion: Vector3) -> bool:
	var origin: Transform3D = global_transform
	var up_motion: Vector3 = Vector3.UP * step_height
	var up_test: Dictionary = _test_motion(origin, up_motion)

	var actual_up: Vector3 = up_motion
	if _result_collided(up_test):
		actual_up = _result_travel(up_test)

	if actual_up.y < 0.05:
		return false

	var raised: Transform3D = origin.translated(actual_up)
	var forward_motion: Vector3 = h_motion * step_forward_probe
	var fwd_test: Dictionary = _test_motion(raised, forward_motion)

	var actual_fwd: Vector3 = forward_motion
	if _result_collided(fwd_test):
		actual_fwd = _result_travel(fwd_test)

	if actual_fwd.length_squared() < 0.000001:
		return false

	var advanced: Transform3D = raised.translated(actual_fwd)
	var down_motion: Vector3 = Vector3.DOWN * (actual_up.y + step_down_extra)
	var down_test: Dictionary = _test_motion(advanced, down_motion)

	if not _result_collided(down_test):
		return false

	var down_normal: Vector3 = _result_normal(down_test)
	if down_normal.angle_to(Vector3.UP) > floor_max_angle:
		return false

	var final_transform: Transform3D = advanced.translated(_result_travel(down_test))

	if final_transform.origin.y < origin.origin.y - 0.01:
		return false

	global_transform = final_transform
	velocity.y = 0.0
	apply_floor_snap()
	return true

func _try_step_down() -> void:
	var down_motion: Vector3 = Vector3.DOWN * (step_height + step_down_extra)
	var down_test: Dictionary = _test_motion(global_transform, down_motion)

	if not _result_collided(down_test):
		return

	var down_normal: Vector3 = _result_normal(down_test)
	if down_normal.angle_to(Vector3.UP) > floor_max_angle:
		return

	global_transform = global_transform.translated(_result_travel(down_test))
	velocity.y = 0.0
	apply_floor_snap()

func _test_motion(from: Transform3D, motion: Vector3) -> Dictionary:
	var params: PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	params.margin = safe_margin

	var result: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	var collided: bool = PhysicsServer3D.body_test_motion(get_rid(), params, result)

	var travel: Vector3 = motion
	var normal: Vector3 = Vector3.UP

	if collided:
		travel = result.get_travel()
		normal = result.get_collision_normal()

	return {
		"collided": collided,
		"travel": travel,
		"normal": normal
	}

func _result_collided(data: Dictionary) -> bool:
	return data["collided"]

func _result_travel(data: Dictionary) -> Vector3:
	return data["travel"]

func _result_normal(data: Dictionary) -> Vector3:
	return data["normal"]
