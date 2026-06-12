extends CharacterBody3D

@export var mouse_sensitivity: float = 0.002
@export var speed: float = 6.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 18.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D

var pitch: float = 0.0

func _ready() -> void:
 Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
  rotate_y(-event.relative.x * mouse_sensitivity)

  pitch -= event.relative.y * mouse_sensitivity
  pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
  head.rotation.x = pitch

 if event.is_action_pressed("ui_cancel"):
  Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

 if event.is_action_pressed("shoot"):
  shoot()

func _physics_process(delta: float) -> void:
 if not is_on_floor():
  velocity.y -= gravity * delta

 if Input.is_action_just_pressed("jump") and is_on_floor():
  velocity.y = jump_velocity

 var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
 var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

 if direction:
  velocity.x = direction.x * speed
  velocity.z = direction.z * speed
 else:
  velocity.x = move_toward(velocity.x, 0, speed)
  velocity.z = move_toward(velocity.z, 0, speed)

 move_and_slide()

func shoot() -> void:
 ray.force_raycast_update()

 if ray.is_colliding():
  var collider = ray.get_collider()
  print("Hit: ", collider.name)

  if collider.has_method("take_damage"):
   collider.take_damage(25)
