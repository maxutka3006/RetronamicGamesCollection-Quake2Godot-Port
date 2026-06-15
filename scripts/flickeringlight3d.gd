extends Light3D
class_name FlickeringLight3D

# -------------------------------------------------- Flicker Settings
@export_group("Flicker")
@export var flicker_enabled: bool = true
@export var min_energy: float = 0.2
@export var max_energy: float = 1.5
@export var flicker_speed: float = 10.0          # Base speed of flickering
@export var flicker_smoothness: float = 0.3      # 0 = abrupt (Quake-style), 1 = very smooth
@export var random_seed: int = 0                 # Set for reproducible patterns

# -------------------------------------------------- Internal
var _base_energy: float
var _target_energy: float

func _ready():
	_base_energy = light_energy
	_target_energy = _base_energy

	# Initialize randomness
	if random_seed != 0:
		seed(random_seed)

func _process(delta: float) -> void:
	if not flicker_enabled:
		return

	# Choose new target energy randomly at intervals
	if randf() < flicker_speed * delta:
		_target_energy = randf_range(min_energy, max_energy)

	# Smoothly interpolate towards target energy (Quake is more abrupt, so use low smoothness)
	var blend = 1.0 - exp(-delta * (1.0 / max(flicker_smoothness, 0.01)))
	light_energy = lerp(light_energy, _target_energy, blend)
