extends CharacterBody3D

var speed = 0.0
const WALK_SPEED = 5.0

const SPRINT_SPEED = 9.0

const CROUCH_SPEED = 3.0
const CROUCH_DEPTH = -0.7

const LERP_SPEED = 8.0

var slide_timer = 0.0
var slide_vector = Vector2.ZERO
var slide_speed = 10.0
const SLIDE_TIMER_MAX = 1.0

const JUMP_VELOCITY = 4.5

const SENSITIVITY = 0.04
const BASE_FOV = 75.0
const FOV_CHANGE = 2.5

const FREE_LOOK_TILT = 6.0

const GRAVITY = 9.8

# States

var is_walking = false
var is_sprinting = false
var is_crouching = false
var is_free_looking = false
var is_sliding = false

# Bullets
var bullet = load("res://scenes/bullet_default.tscn")
var instance

# Player nodes
@onready var neck = $Neck
@onready var head = $Neck/Head
@onready var camera = $Neck/Head/Camera3D
@onready var hitbox_collision = $HitboxComponent/hitboxCollision
@onready var standing_collision = $standingCollision
@onready var crouching_collision = $crouchingCollision
@onready var standing_ray_cast = $standingRayCast
@onready var sliding_ray_cast = $slidingRayCast
@onready var rifle_anim = $Neck/Head/Camera3D/Rifle/AnimationPlayer
@onready var rifle_barrel = $Neck/Head/Camera3D/Rifle/RayCast3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		if is_free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * SENSITIVITY))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-120), deg_to_rad(120))

		else:
			rotate_y(deg_to_rad(-event.relative.x * SENSITIVITY))
			head.rotate_x(deg_to_rad(-event.relative.y * SENSITIVITY))
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta):
	
	# Get the input direction and handle the movement/deceleration.
	var input_dir = Input.get_vector("StrafeLeft", "StrafeRight", "Forward", "Backward")
	var direction = transform.basis * Vector3(input_dir.x, 0, input_dir.y).normalized()

	# Add the gravity.
	velocity.y -= GRAVITY * delta

	print(speed)

	# Crouching
	if Input.is_action_pressed("Crouch"):
		# && !is_sprinting
		crouch(delta)
	#if Input.is_action_pressed("Crouch") && is_sprinting:
		#slide(delta)

	# Uncrouching
	if !Input.is_action_pressed("Crouch") && !standing_ray_cast.is_colliding() && !is_walking:
		uncrouch(delta)

	# Sprinting
	if Input.is_action_pressed("Sprint") && is_on_floor() && !is_crouching:
		sprint(delta)
			
	if !Input.is_action_pressed("Sprint") && !is_sprinting && !is_crouching && !is_sliding:
		print('walking')
		speed = lerp(speed, WALK_SPEED, delta * LERP_SPEED)
		is_walking = true

	# Jumping
	if Input.is_action_just_pressed("Jump") && is_on_floor():
		jump()

	# Free Looking
	if Input.is_action_pressed("Free_Look"):
		is_free_looking = true
		
		if is_sliding:
			camera.rotation.z = lerp(camera.rotation.z, -deg_to_rad(7.0), delta * LERP_SPEED)
		else:
			camera.rotation.z = -deg_to_rad(neck.rotation.y * FREE_LOOK_TILT)
			
	else:
		is_free_looking = false
		neck.rotation.y = lerp(neck.rotation.y, 0.0, delta * LERP_SPEED)
		camera.rotation.z = lerp(camera.rotation.y, 0.0, delta * LERP_SPEED)
		

	if is_sliding:
		direction = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
		speed = slide_speed
		
		# Adjust air control
		var air_control = 1.0
		if !is_on_floor():
			air_control = 0.2  # Adjust this value as needed

		velocity.x = lerp(velocity.x, direction.x * speed, delta * air_control)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * air_control)
	
	if velocity.length() <= CROUCH_SPEED:
		is_sliding = false
		camera.rotation.y = lerp(camera.rotation.y, -deg_to_rad(neck.rotation.y), delta * LERP_SPEED)

	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			
	else:
		# Adjust these to change mid-air movement control
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 0.5)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 0.5)
		
		
	# Shooting
	if Input.is_action_pressed("Shoot"):
		if !rifle_anim.is_playing():
			rifle_anim.play("Shoot")
			instance = bullet.instantiate()
			instance.position = rifle_barrel.global_position
			instance.transform.basis = rifle_barrel.global_transform.basis
			get_parent().add_child(instance)

	# FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped 
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	move_and_slide()

func jump():
	velocity.y = JUMP_VELOCITY
	is_sliding = false

func crouch(delta):
	if is_on_floor():
		print('crouching')
		is_crouching = true
		is_walking = false
		is_sprinting = false
		speed = lerp(speed, CROUCH_SPEED, delta * LERP_SPEED)
		head.position.y = lerp(head.position.y, CROUCH_DEPTH, delta * LERP_SPEED)
		
		standing_collision.disabled = true
		crouching_collision.disabled = false
	else: 
		print('cant crouch in air')

func slide(delta):
	# Gradually reduce the speed from sprinting speed to crouching speed
	speed = lerp(speed, CROUCH_SPEED, delta * LERP_SPEED)
	
	# Check if the speed has reached or fallen below crouching speed
	if speed <= CROUCH_SPEED:
		is_crouching = true
		speed = CROUCH_SPEED  # Ensure speed is exactly CROUCH_SPEED
		head.position.y = lerp(head.position.y, CROUCH_DEPTH, delta * LERP_SPEED)
		standing_collision.disabled = true
		crouching_collision.disabled = false

func uncrouch(delta):
	print('uncrouching')
	# Standing
	is_crouching = false
	head.position.y = lerp(neck.position.y, 0.0, delta * LERP_SPEED)
	standing_collision.disabled = false
	crouching_collision.disabled = true

func sprint(delta):
	print('sprinting')
	speed = lerp(speed, SPRINT_SPEED, delta * LERP_SPEED)	
	is_walking = false
	is_sprinting = true
	is_crouching = false
