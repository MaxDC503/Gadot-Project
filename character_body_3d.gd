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

# camera variables
const MAX_LOOK_ANGLE = 90
const MIN_LOOK_ANGLE = -90
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

const GRAVITY = 9.8

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var jumpChargeBar = $"../CanvasLayer/ProgressBar"

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else: 
		speed = WALK_SPEED
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * GROUND_STOP_FORCE)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * GROUND_STOP_FORCE)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * AIR_STOP_FORCE)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * AIR_STOP_FORCE)
		
		# Handle jump.
	if Input.is_action_pressed("jump"): #and is_on_floor():
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
		jumpMult = 1.0
		jumpChargeBar.value = jumpMult
	
		
		
	t_bob += delta * velocity.length() * float(is_on_floor())
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
