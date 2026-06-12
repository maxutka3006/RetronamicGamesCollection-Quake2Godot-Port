extends CanvasLayer

# Опциональные ссылки — можно задать вручную в инспекторе
@export var ammo_container: Control = null
@export var magazine_label: Label = null
@export var reserve_label: Label = null

var current_weapon: Weapon = null

func _ready():
	# Если ссылки не заданы в инспекторе, пытаемся найти их автоматически
	if not ammo_container:
		ammo_container = get_node_or_null("AmmoContainer")
	if not magazine_label and ammo_container:
		magazine_label = ammo_container.get_node_or_null("MagazineLabel")
	if not reserve_label and ammo_container:
		reserve_label = ammo_container.get_node_or_null("ReserveLabel")

func set_weapon(weapon: Weapon):
	current_weapon = weapon
	update_visibility()

func update_visibility():
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

func _process(_delta):
	# Обновляем текст каждый кадр, только если есть активное оружие и оно показывает аммуницию
	if current_weapon and current_weapon.shows_ammo():
		if magazine_label:
			magazine_label.text = str(current_weapon.current_magazine)
		if reserve_label:
			if current_weapon.infinite_ammo:
				reserve_label.text = "∞"
			else:
				reserve_label.text = str(current_weapon.reserve_ammo)
