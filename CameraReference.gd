extends Spatial

const SENSITIVITY_ROTATION := 0.3
const SENSITIVITY_TRANSLATION := 0.02
const FLY_SPEED := 0.1
const MIN_DISTANCE := 4.0
const MAX_DISTANCE := 100.0
const START_POSITION := Vector3(0, 4, 10)
var initial_transform : Transform
var camera : Camera

func _ready():
	camera = $CameraReference2/Camera
	initial_transform = camera.transform

func _process(_delta) -> void:
	if Input.is_action_pressed("move_forward"):
		camera.transform.origin.z = max(MIN_DISTANCE, camera.transform.origin.z - FLY_SPEED)

	if Input.is_action_pressed("move_backward"):
		camera.transform.origin.z = min(MAX_DISTANCE, camera.transform.origin.z + FLY_SPEED)

	if Input.is_action_pressed("reset_position"):
		transform = Transform.IDENTITY
		$CameraReference2.transform = Transform.IDENTITY
		camera.transform = initial_transform

var mouse_status := 0
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var em := event as InputEventMouseButton
		mouse_status = 0
		if em.pressed:
			match em.button_index:
				BUTTON_MIDDLE:
					mouse_status = 1
				BUTTON_RIGHT:
					mouse_status = 2
				BUTTON_WHEEL_UP:
					camera.transform.origin.z = max(MIN_DISTANCE, camera.transform.origin.z - 5*FLY_SPEED)
				BUTTON_WHEEL_DOWN:
					camera.transform.origin.z = min(MAX_DISTANCE, camera.transform.origin.z + 5*FLY_SPEED)

	if event is InputEventMouseMotion:
		var mouse_move : Vector2 = event.relative
		if mouse_status == 1:
			# yes, I'm too lazy to calculate rotations using
			# transforms or quaternions...
			rotate_y(deg2rad(-mouse_move.x * SENSITIVITY_ROTATION))
			$CameraReference2.rotate_x(deg2rad(-mouse_move.y * SENSITIVITY_ROTATION))
		elif mouse_status == 2:
			transform.origin.x -= mouse_move.x * SENSITIVITY_TRANSLATION
			transform.origin.y += mouse_move.y * SENSITIVITY_TRANSLATION
