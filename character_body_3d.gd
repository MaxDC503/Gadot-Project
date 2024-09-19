extends CharacterBody3D

# physics variables
var speed 
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const AIR_SPEED = 2.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.005
const AIR_STOP_FORCE = 1.5
const GROUND_STOP_FORCE = 7.0
const MAX_VELOCITY = SPRINT_SPEED * 2.0
var jumpMult = 1.0
const MAX_JUMP_MULT = 2.0
const JUMP_MULT_SCALAR = 0.025
const JUMP_MULT_HORIZONTAL = 3.5

# wall run variables
const MIN_WALL_RUN_VELOCITY = 2.0
const WALL_RUN_STOP_FORCE = 0.5
var isWallRunning = false
var currentWallNormal
var lastWallNormal

# camera variables
const MAX_LOOK_ANGLE = 90
const MIN_LOOK_ANGLE = -90
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5
var original_camera_rotation

const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

const GRAVITY = 9.8

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var jumpChargeBar = $"../CanvasLayer/ProgressBar"

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	original_camera_rotation = camera.rotation

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(MIN_LOOK_ANGLE), deg_to_rad(MAX_LOOK_ANGLE))

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	
	# Handle sprint.
	if Input.is_action_pressed("sprint") and not isWallRunning:
		speed = SPRINT_SPEED
	else: 
		speed = WALK_SPEED
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor() and not isWallRunning:
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * GROUND_STOP_FORCE)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * GROUND_STOP_FORCE)
	elif isWallRunning:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * WALL_RUN_STOP_FORCE)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * WALL_RUN_STOP_FORCE)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * AIR_STOP_FORCE)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * AIR_STOP_FORCE)
	
	# Handle jump.
	if Input.is_action_pressed("jump"):
		if jumpMult <= MAX_JUMP_MULT:
			jumpMult = lerp(jumpMult, MAX_JUMP_MULT, JUMP_MULT_SCALAR)
			jumpChargeBar.max_value = MAX_JUMP_MULT
			jumpChargeBar.min_value = 1
			jumpChargeBar.value = jumpMult
	elif Input.is_action_just_released("jump"):
		if is_on_floor():
			velocity.y += JUMP_VELOCITY * jumpMult
			velocity.x += direction.x * jumpMult * JUMP_MULT_HORIZONTAL
			velocity.z += direction.z * jumpMult * JUMP_MULT_HORIZONTAL
		elif isWallRunning:
			velocity.y += JUMP_VELOCITY * jumpMult
			velocity.x += direction.x * jumpMult * JUMP_MULT_HORIZONTAL + get_wall_normal().x * 10
			velocity.z += direction.z * jumpMult * JUMP_MULT_HORIZONTAL + get_wall_normal().z * 10
			
		jumpMult = 1.0
		jumpChargeBar.value = jumpMult
	
	# Handle Wallrun.
	var kVec = Vector3(0, 0, 1)
	var horizontalSpeed = Vector3(velocity.x, 0, velocity.z).length()
	var cameraVector = camera.get_global_transform().basis.z
	if is_on_floor():
		lastWallNormal = null 
		currentWallNormal = null
	elif not isWallRunning:
		lastWallNormal = currentWallNormal

	if is_on_wall_only() and not lastWallNormal == get_wall_normal() and horizontalSpeed > WALK_SPEED + 0.5:
		isWallRunning = true
		currentWallNormal = get_wall_normal()
		var temp = currentWallNormal.cross(kVec)
		var leftOrRightVector = direction.cross(currentWallNormal)
		if leftOrRightVector.y > 0:
			print("Right")
			camera.rotation.z = lerp(camera.rotation.z, kVec.rotated(temp, PI/6).z / 2, 0.25)
		else:
			print("Left")
			camera.rotation.z = lerp(camera.rotation.z, -kVec.rotated(temp, PI/6).z / 2, 0.25)
		
		if velocity.y > 0.0: 
			velocity.y = lerp(velocity.y, 0.0, 0.01)
		else:
			velocity.y = 0.0
	else: 
		camera.rotation = lerp(camera.rotation, original_camera_rotation, 0.05)
		isWallRunning = false

	t_bob += delta * velocity.length() * float(is_on_floor() or isWallRunning)
	camera.transform.origin = _headbob(t_bob)

	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, MAX_VELOCITY)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	move_and_slide()
	
func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
	
