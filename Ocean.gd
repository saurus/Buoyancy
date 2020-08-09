#tool
extends ImmediateGeometry
class_name Ocean

const NUMBER_OF_WAVES := 2
const AMPLITUDE := 0
const FREQUENCY := 1
const STEEPNESS := 2
const WIND_DIRECTIONX := 3
const WIND_DIRECTIONY:= 4

export(float, 0, 10000) var wavelength_base := 60.0
export(float, 0, 1) var steepness_base := 0.01
export(float, 0, 10000) var amplitude_base := 0.05
export(Vector2) var wind_direction_base := Vector2(1, 0)
export(float, 0, 1) var wind_align := 0.0
export(float) var speed := 10.0

export(float) var noise_amplitude := 0.28
export(float) var noise_frequency := 0.065
export(float) var noise_speed := 0.48

onready var root = $".."
onready var dbgLabel :=  $"../DebugLabel"

var res := 100.0
var wd_amplitude: Array
var wd_frequency: Array
var wd_steepness: Array
var wd_wind_directionX: Array
var wd_wind_directionY: Array
var init_done := false

func view_toggler_activated():
	self.visible = !self.visible

func _ready() -> void:
	randomize()
	for j in range(res):
		var y := j/res - 0.5
		var n_y := (j+1)/res - 0.5
		begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in range(res):
			var x := i/res - 0.5

			add_vertex(Vector3(x*2, 0, -y*2))
			add_vertex(Vector3(x*2, 0, -n_y*2))
		end()
	begin(Mesh.PRIMITIVE_POINTS)
	add_vertex(-Vector3(1,1,1)*pow(2,32))
	add_vertex(Vector3(1,1,1)*pow(2,32))
	end()
	for _i in range(NUMBER_OF_WAVES):
		wd_amplitude.push_back(Plane(0,0,0,0))
		wd_frequency.push_back(Plane(0,0,0,0))
		wd_steepness.push_back(Plane(0,0,0,0))
		wd_wind_directionX.push_back(Plane(0,0,0,0))
		wd_wind_directionY.push_back(Plane(0,0,0,0))

	update_waves()

	material_override.set_shader_param('waves_vectors', NUMBER_OF_WAVES)
	init_done = true

var current = null
var flag_debug_mesh := false
var flag_debug_draw := false
func set_object(name: String) -> void:
	if current:
		current.queue_free()
		var tr := []
		for n in root.get_children():
			if "submerged" in n.name: # fixme: find a better way to identify buoyancy shapes...
				tr.append(n)
		for n in tr:
			n.queue_free()
		current.queue_free()
	current = load("res://objects/" + name +".tscn").instance()
	root.add_child(current)
	current.init(get_parent(), $"../Ocean", $"../DebugLabel", $"../RefPlane2",$"../BuoyancyForce")
	current.set_debug(flag_debug_mesh, flag_debug_draw, dbgLabel)

func set_debug(enabled_mesh: bool, enabled_draw: bool) -> void:
	flag_debug_mesh = enabled_mesh
	flag_debug_draw = enabled_draw
	if current:
		current.set_debug(flag_debug_mesh, flag_debug_draw, dbgLabel)

func _process(_delta: float) -> void:
	material_override.set_shader_param('time_offset', OS.get_ticks_msec()/1000.0 * speed)

func set_wavelength(value: float) -> void:
	wavelength_base = value
	update_amplitude_frequency_all()

func set_steepness(value: float) -> void:
	steepness_base = value
	update_steepness_all()

func set_amplitude(value: float) -> void:
	amplitude_base = value
	update_amplitude_frequency_all()

func set_wind_directionX(value: float) -> void:
	wind_direction_base.x = value
	update_wind_direction_all()

func set_wind_directionY(value: float) -> void:
	wind_direction_base.y = value
	update_wind_direction_all()

func set_wind_align(value: float) -> void:
	wind_align = value
	update_wind_direction_all()

func set_speed(value: float) -> void:
	speed = value
	material_override.set_shader_param('speed', value)

func set_noise_amplitude(value: float) -> void:
	noise_amplitude = value
	material_override.set_shader_param('noise_amplitude', noise_amplitude)

func set_noise_frequency(value: float) -> void:
	noise_frequency = value
	material_override.set_shader_param('noise_frequency', noise_frequency)

func set_noise_speed(value: float) -> void:
	noise_speed = value
	material_override.set_shader_param('noise_speed', noise_speed)

func waves_calc(amp: float, steep: float, windX: float, windY: float, w: float, pos: Vector2, time: float) -> Vector3:
	var r := Vector3()
	var dir := Vector2(windX, windY)
	var phase := 2.0 * w
	var W := pos.dot(w*dir) + phase*time
	r.x = (steep/w) * dir.x * cos(W)
	r.z = (steep/w) * dir.y * cos(W)
	r.y = amp * sin(W)
	return r

func wave_v4(new_p: Vector3, amplitude: Plane, steepness: Plane, windX: Plane, windY: Plane, frequency: Plane, pos: Vector2, time: float) -> Vector3:
	new_p += waves_calc(amplitude.x, steepness.x, windX.x, windY.x, frequency.x, pos, time)
	new_p += waves_calc(amplitude.y, steepness.y, windX.y, windY.y, frequency.y, pos, time)
	new_p += waves_calc(amplitude.z, steepness.z, windX.z, windY.z, frequency.z, pos, time)
	new_p += waves_calc(amplitude.d, steepness.d, windX.d, windY.d, frequency.d, pos, time)
	return new_p

func get_displace(position: Vector2) -> Vector3:
	var new_p := Vector3(position.x, 0.0, position.y)

	if init_done:
		var time := OS.get_ticks_msec()/1000.0 * speed
		for i in range(NUMBER_OF_WAVES):
			new_p = wave_v4(new_p, wd_amplitude[i], wd_steepness[i]
			, wd_wind_directionX[i], wd_wind_directionY[i], wd_frequency[i]
			, position, time)

	return new_p

func update_waves() -> void:
	#Generate Waves..
	update_amplitude_frequency_all()
	update_steepness_all()
	update_wind_direction_all()

func update_amplitude_frequency_all() -> void:
	var amp_length_ratio := amplitude_base / wavelength_base
	var amplitude := Plane(0,0,0,0)
	var frequency := Plane(0,0,0,0)
	var _wavelength : float
	var wl_half := wavelength_base/2.0
	var wl_double := wavelength_base*2.0

	for i in range(NUMBER_OF_WAVES):
		_wavelength = rand_range(wl_half, wl_double)
		amplitude.x = amp_length_ratio * _wavelength
		frequency.x = sqrt(0.098 * TAU/_wavelength)

		_wavelength = rand_range(wl_half, wl_double)
		amplitude.y = amp_length_ratio * _wavelength
		frequency.y = sqrt(0.098 * TAU/_wavelength)

		_wavelength = rand_range(wl_half, wl_double)
		amplitude.z = amp_length_ratio * _wavelength
		frequency.z = sqrt(0.098 * TAU/_wavelength)

		_wavelength = rand_range(wl_half, wl_double)
		amplitude.d = amp_length_ratio * _wavelength
		frequency.d = sqrt(0.098 * TAU/_wavelength)

		wd_amplitude[i] = amplitude
		material_override.set_shader_param('amplitude' + str(i), amplitude)
		wd_frequency[i] = frequency
		material_override.set_shader_param('frequency' + str(i), frequency)

func update_steepness_all() -> void:
	var steepness := Plane(0,0,0,0)

	for i in range(NUMBER_OF_WAVES):
		steepness.x = rand_range(0, steepness_base)
		steepness.y = rand_range(0, steepness_base)
		steepness.z = rand_range(0, steepness_base)
		steepness.d = rand_range(0, steepness_base)
		wd_steepness[i] = steepness
		material_override.set_shader_param('steepness' + str(i), steepness)

func update_wind_direction_all() -> void:
	var _wind_direction : Vector2
	var wind_directionX := Plane(0,0,0,0)
	var wind_directionY := Plane(0,0,0,0)

	for i in range(NUMBER_OF_WAVES):
		_wind_direction = wind_direction_base.rotated(rand_range(-PI, PI)*(1-wind_align))
		wind_directionX.x = _wind_direction.x
		wind_directionY.x = _wind_direction.y

		_wind_direction = wind_direction_base.rotated(rand_range(-PI, PI)*(1-wind_align))
		wind_directionX.y = _wind_direction.x
		wind_directionY.y = _wind_direction.y

		_wind_direction = wind_direction_base.rotated(rand_range(-PI, PI)*(1-wind_align))
		wind_directionX.z = _wind_direction.x
		wind_directionY.z = _wind_direction.y

		_wind_direction = wind_direction_base.rotated(rand_range(-PI, PI)*(1-wind_align))
		wind_directionX.d = _wind_direction.x
		wind_directionY.d = _wind_direction.y

		wd_wind_directionX[i] = wind_directionX
		material_override.set_shader_param('wind_directionX' + str(i), wind_directionX)
		wd_wind_directionY[i] = wind_directionY
		material_override.set_shader_param('wind_directionY' + str(i), wind_directionY)
