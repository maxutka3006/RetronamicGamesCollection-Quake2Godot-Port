extends CharacterBody3D

# --- Мышь ---
@export var mouse_sensitivity: float = 0.0025

# --- Физика ---
@export var gravity: float = 20.0
@export var jump_velocity: float = 8.5

# --- Движение (Quake-style) ---
@export var ground_speed: float = 10.0
@export var ground_accel: float = 75.0
@export var air_speed: float = 1.0       # wish_speed в воздухе (ключ к strafe jump)
@export var air_accel: float = 20.0
@export var friction: float = 8.0
@export var stop_speed: float = 3.0

# --- Стрельба ---
@export var shoot_damage: int = 25

@onready var head: Node3D = $Head
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var cooldown: Timer = $WeaponCooldown

var pitch: float = 0.0

func _ready() -> void:
 max_slides = 8

 Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
 # --- Камера ---
 if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
  rotate_y(-event.relative.x * mouse_sensitivity)
  pitch = clamp(pitch - event.relative.y * mouse_sensitivity,
	   deg_to_rad(-89.0), deg_to_rad(89.0))
  head.rotation.x = pitch

 # --- Курсор ---
 if event.is_action_pressed("ui_cancel"):
  Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

 # --- Стрельба ---
 if event.is_action_pressed("shoot") and cooldown.is_stopped():
  _shoot()

func _physics_process(delta: float) -> void:
 var wish_dir := _get_wish_dir()

 if is_on_floor():
  # Трение — только на земле
  _apply_friction(delta)
  # Ускорение по земле
  _accelerate(wish_dir, ground_speed, ground_accel, delta)
  # Авто-bhop: держишь прыжок — прыгаешь при касании пола
  if Input.is_action_pressed("jump"):
   velocity.y = jump_velocity
 else:
  # Гравитация
  velocity.y -= gravity * delta
  # В воздухе: air_speed маленький — это даёт strafe jump
  _accelerate(wish_dir, air_speed, air_accel, delta)

 move_and_slide()

# ========== Quake movement core ==========

func _get_wish_dir() -> Vector3:
 var input := Vector2(
  Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
  Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
 )
 if input.is_zero_approx():
  return Vector3.ZERO

 var forward := -global_transform.basis.z
 var right := global_transform.basis.x
 forward.y = 0.0
 right.y = 0.0

 return (right.normalized() * input.x + forward.normalized() * input.y).normalized()

func _apply_friction(delta: float) -> void:
 var hvel := Vector3(velocity.x, 0.0, velocity.z)
 var speed := hvel.length()
 if speed < 0.001:
  return

 var control := maxf(speed, stop_speed)
 var drop := control * friction * delta
 var new_speed := maxf(speed - drop, 0.0) / speed

 velocity.x *= new_speed
 velocity.z *= new_speed

func _accelerate(wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> void:
 if wish_dir.is_zero_approx():
  return

 var current_speed := velocity.dot(wish_dir)
 var add_speed := wish_speed - current_speed
 if add_speed <= 0.0:
  return

 var accel_speed := minf(accel * delta * wish_speed, add_speed)
 velocity += wish_dir * accel_speed

# ========== Стрельба ==========

func _shoot() -> void:
 cooldown.start()
 ray.force_raycast_update()

 if ray.is_colliding():
  var collider := ray.get_collider()
  if collider and collider.has_method("take_damage"):
   collider.take_damage(shoot_damage)
  print("Hit: ", collider.name if collider else "nothing")
