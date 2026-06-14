extends CanvasLayer

@export var ammo_container: Control = null
@export var magazine_label: Label = null
@export var reserve_label: Label = null
@export var crosshair: Control = null

var current_weapon: Weapon = null

func _ready():
	if not ammo_container:
		ammo_container = get_node_or_null("AmmoContainer")
	if not magazine_label and ammo_container:
		magazine_label = ammo_container.get_node_or_null("MagazineLabel")
	if not reserve_label and ammo_container:
		reserve_label = ammo_container.get_node_or_null("ReserveLabel")
	if not crosshair:
		crosshair = get_node_or_null("Crosshair")

func set_weapon(weapon: Weapon):
	current_weapon = weapon
	update_visibility()

func update_visibility():
	# Ammo display
	var show_ammo = current_weapon and current_weapon.shows_ammo()
	if ammo_container:
		ammo_container.visible = show_ammo
	if show_ammo and current_weapon:
		if magazine_label:
			magazine_label.text = str(current_weapon.current_magazine)
		if reserve_label:
			if current_weapon.infinite_ammo:
				reserve_label.text = "∞"
			else:
				reserve_label.text = str(current_weapon.reserve_ammo)

	# Crosshair (always show unless weapon explicitly hides it)
	var show_crosshair = current_weapon and current_weapon.shows_crosshair()
	if crosshair:
		crosshair.visible = show_crosshair

func _process(_delta):
	if current_weapon and current_weapon.shows_ammo():
		if magazine_label:
			magazine_label.text = str(current_weapon.current_magazine)
		if reserve_label:
			if current_weapon.infinite_ammo:
				reserve_label.text = "∞"
			else:
				reserve_label.text = str(current_weapon.reserve_ammo)
