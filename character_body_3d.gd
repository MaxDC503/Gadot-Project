extends CharacterBody3D

# physics variables
var speed 
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const WALLRUNNING_SPEED = 3.0
const AIR_SPEED = 2.0
const GRAPPLE_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.005
const AIR_STOP_FORCE = 0.5
const GROUND_STOP_FORCE = 7.0
const MAX_VELOCITY = SPRINT_SPEED * 10
var jumpMult = 1.0
const MAX_JUMP_MULT = 2.0
const JUMP_MULT_SCALAR = 0.025
const JUMP_MULT_HORIZONTAL = 3.5

# wall run variables
const MIN_WALL_RUN_VELOCITY = 2.0
const WALL_RUN_STOP_FORCE = 0.35
var isWallRunning = false
var currentWallNormal
var lastWallNormal

# camera variables
const MAX_LOOK_ANGLE = 90
const MIN_LOOK_ANGLE = -90
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5
var original_head_rotation

const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0

# Grappling variables
var swingRadius = 10.0
var isGrappling = false
var grapplePoint = Vector3(0, 0, 0)
var grapplePullForce = 0.5
var radiusDifference = 0.0
var grapplePullBackSpeed = 0.0
var maxGrappleLength = 50.0

var joint

const GRAVITY = 9.8

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var jumpChargeBar = $"../CanvasLayer/ProgressBar"
@onready var grappleObject = $"../Map/Grapple"
@onready var player = $"."
@onready var dot = $"../Map/Marker"
@onready var rigidBody = $"../RigidBody3D"

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	original_head_rotation = head.rotation

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
	elif isWallRunning:
		speed = WALLRUNNING_SPEED
	elif isGrappling:
		speed = GRAPPLE_SPEED
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
	if is_on_floor() or isWallRunning:
		lastWallNormal = null 
		currentWallNormal = null
	elif not isWallRunning:
		lastWallNormal = currentWallNormal

	if is_on_wall_only() and not lastWallNormal == get_wall_normal() and horizontalSpeed > WALLRUNNING_SPEED + 0.5:
		isWallRunning = true
		currentWallNormal = get_wall_normal()
		var temp = currentWallNormal.cross(kVec)
		var leftOrRightVector = direction.cross(currentWallNormal)
		if leftOrRightVector.y > 0:
			head.rotation.z = lerp(head.rotation.z, kVec.rotated(temp, PI/6).z / 2, 0.25)
		else:
			head.rotation.z = lerp(head.rotation.z, -kVec.rotated(temp, PI/6).z / 2, 0.25)
		
		if velocity.y > 0.0: 
			velocity.y = lerp(velocity.y, 0.0, 0.01)
		else:
			velocity.y = 0.0
	else: 
		head.rotation.z = lerp(head.rotation.z, original_head_rotation.z, 0.05)
		isWallRunning = false

	t_bob += delta * velocity.length() * float(is_on_floor() or isWallRunning)
	camera.transform.origin = _headbob(t_bob)

	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, MAX_VELOCITY)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	# Handle Grappling
	if isGrappling:
		var toGrapple = (grapplePoint - global_transform.origin).normalized()
		var desiredPosition = grapplePoint
		var currentPosition = global_transform.origin
		
		var distance = currentPosition.distance_to(desiredPosition)
		var projectedVector = ((cameraVector - toGrapple) * cameraVector.dot(toGrapple)).normalized()
		var midpoint = (currentPosition + grapplePoint) / 2
		
		velocity += toGrapple * grapplePullForce
		
		grappleObject.visible = true
		grappleObject.scale = Vector3(0.5, 0.5, distance * 5)
		grappleObject.global_transform.origin = midpoint
		var grappleDirection = (desiredPosition - currentPosition).normalized()
		grappleObject.look_at(desiredPosition, Vector3(0, 1, 0))
	else:
		grappleObject.visible = false
	
	move_and_slide()
	
func _input(event):
	if Input.is_action_just_pressed("Grapple") and not isGrappling and not event.is_class("InputEventKey"):
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * maxGrappleLength
		#dot = $"../Map/Marker"
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space_state.intersect_ray(query)
		if result:
			isGrappling = true
			grapplePoint = result.position
			#dot.position = result.position
	elif Input.is_action_just_released("Grapple"):
		isGrappling = false

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
	
