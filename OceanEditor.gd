extends Panel

onready var ocean : Ocean = $"../Ocean"
onready var buttonGroup

func _ready():
	create_buttons()

func _on_amplitude_changed(value: float) -> void:
	ocean.set_amplitude(value)

func _on_wavelength_changed(value: float) -> void:
	ocean.set_wavelength(value)

func _on_stepness_changed(value: float) -> void:
	ocean.set_steepness(value)

func _on_windX_changed(value: float) -> void:
	ocean.set_wind_directionX(value)

func _on_windY_changed(value: float) -> void:
	ocean.set_wind_directionY(value)

func _on_windalign_changed(value: float) -> void:
	ocean.set_wind_align(value)

func _on_speed_changed(value: float) -> void:
	ocean.set_speed(value)

func _on_noise_amp_changed(value: float) -> void:
	ocean.set_noise_amplitude(value)

func _on_noise_freq_changed(value: float) -> void:
	ocean.set_noise_frequency(value)

func _on_noise_speed_changed(value: float) -> void:
	ocean.set_noise_speed(value)

func _on_object_pressed():
	ocean.set_object(buttonGroup.get_pressed_button().name.substr(1))

func create_buttons():
	buttonGroup = ButtonGroup.new()
	var names := dir_contents("res://objects")
	for name in names:
		var button = Button.new()
		button.name = "b" + name
		button.text = name
		button.toggle_mode = true
		button.group = buttonGroup
		button.connect("pressed", self, "_on_object_pressed")
		$Settings.add_child(button)

func dir_contents(path : String) -> Array:
	var names := []
	var dir := Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tscn"):
				print("Found file: " + file_name)
				var name := file_name.substr(0,file_name.length()-5)
				names.append(name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	names.sort()
	return names

func _on_bViewSea_toggled(button_pressed):
	ocean.visible = button_pressed

func _on_bViewBuoyancy_toggled(button_pressed):
	ocean.set_debug($Settings/bViewBuoyancy.pressed, $Settings/bViewDraw.pressed)
