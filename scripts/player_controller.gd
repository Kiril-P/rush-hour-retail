extends CharacterBody3D

signal interact_object

@onready var camera_3d = $Camera3D
@onready var ray_cast_3d = $Camera3D/RayCast3D
@onready var build_component = $BuildComponent
@onready var interaction_component = $InteractionComponent

const SPEED = 1.8
const SPRINT_SPEED = 3.5
const CROUCH_SPEED = 1.2
const JUMP_VELOCITY = 3.0
const CAMERA_SENS = 0.001

# Head Bobbing Constants
const BOB_FREQ = 3.0
const BOB_AMP = 0.04
var t_bob = 0.0

# Crouching Constants
const CROUCH_HEIGHT = 0.4
const STAND_HEIGHT = 0.8
const CROUCH_CAM_Y = 0.1
const STAND_CAM_Y = 0.3
var is_crouching = false

# Movement Feel
const ACCEL = 10.0
const FRICTION = 8.0
const AIR_CONTROL = 0.3

# Feedback
const BASE_FOV = 75.0
const SPRINT_FOV = 85.0
const LEAN_AMOUNT = 0.015
const LANDING_DIP = 0.05

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var collider = null
var interact_button_pressed_time = 0.0
var secondary_interact_pressed_time = 0.0
var was_on_floor = true

@onready var collision_shape_3d = $CollisionShape3D

func _ready():
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Move to spawn point on start
	await get_tree().process_frame
	var spawn = get_tree().current_scene.find_child("PlayerSpawnPoint")
	if spawn:
		global_position = spawn.global_position
		rotation.y = spawn.rotation.y
		
	build_component.ray_cast_3d = ray_cast_3d
	build_component.build_preview_marker = $Camera3D/BuildPreviewMarker

func _input(event):
	if event.is_action_pressed("quit"): get_tree().quit()

	# 1. HANDLE SHOP TOGGLE FIRST (so 'B' can close it)
	if event.is_action_pressed("shop"):
		$CanvasLayer/ShopUI.toggle()
		return

	# 2. DISABLE OTHER INPUTS IF SHOP IS OPEN
	if $CanvasLayer/ShopUI.visible:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * CAMERA_SENS)
		camera_3d.rotate_x(-event.relative.y * CAMERA_SENS)
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event.is_action_pressed("build_mode"):
		build_component.toggle_build_mode()
	
	if build_component.is_building:
		handle_build_input(event)
		return 

	if event.is_action_pressed("interact"):
		interact_button_pressed_time = Time.get_ticks_msec()
	
	if event.is_action_released("interact"):
		var hold_duration = (Time.get_ticks_msec() - interact_button_pressed_time) / 1000.0
		interaction_component.handle_interaction(collider, hold_duration, false)
	
	if event.is_action_pressed("secondary_interact"):
		secondary_interact_pressed_time = Time.get_ticks_msec()
	
	if event.is_action_released("secondary_interact"):
		var hold_duration = (Time.get_ticks_msec() - secondary_interact_pressed_time) / 1000.0
		interaction_component.handle_interaction(collider, hold_duration, true)
func handle_build_input(event):
	# Rotate (Now 45 degrees inverted)
	if event.is_action_pressed("rotate_object"): 
		build_component.rotate_ghost()
	
	# Place / Confirm Move
	if event.is_action_pressed("interact"): # Left Click
		build_component.place_item()
		
	# Delete / Cancel Move
	if event.is_action_pressed("secondary_interact"): # Right Click
		if build_component.moving_item:
			build_component.cancel_move()
		else:
			build_component.delete_item(collider)
			
	# Pick up to Move
	if event.is_action_pressed("middle_click"):
		build_component.pick_up_to_move(collider)

	if event.is_action_pressed("next_item"): build_component.cycle_items(1)
	if event.is_action_pressed("prev_item"): build_component.cycle_items(-1)

	# NEW: Toggle Snap with Ctrl
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_CTRL:
			build_component.cycle_snap()

func _physics_process(delta):
	if $CanvasLayer/ShopUI.visible:
		# Apply ONLY gravity so player falls to floor but cannot move
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0
		
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	# 1. HANDLE STATES (Sprint/Crouch)
	var current_speed = SPEED
	if Input.is_action_pressed("crouch"):
		current_speed = CROUCH_SPEED
		is_crouching = true
	elif Input.is_action_pressed("sprint") and not is_crouching:
		current_speed = SPRINT_SPEED
		is_crouching = false
	else:
		is_crouching = false

	# 2. SMOOTH CROUCHING (Height & Camera)
	var target_height = CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	var target_cam_y = CROUCH_CAM_Y if is_crouching else STAND_CAM_Y
	
	# Interpolate Collision Shape (Make sure it's unique in editor if needed)
	collision_shape_3d.shape.height = lerp(collision_shape_3d.shape.height, target_height, delta * 12.0)
	
	# 3. GRAVITY & LANDING FEEL
	if not is_on_floor():
		velocity.y -= gravity * delta
		was_on_floor = false
	else:
		if not was_on_floor: # Just landed!
			_apply_landing_effects()
			was_on_floor = true
		
		if Input.is_action_just_pressed("ui_accept") and not is_crouching:
			velocity.y = JUMP_VELOCITY

	# 4. MOVEMENT LOGIC (With Acceleration/Friction)
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var accel_to_use = ACCEL if is_on_floor() else ACCEL * AIR_CONTROL
	var friction_to_use = FRICTION if is_on_floor() else FRICTION * AIR_CONTROL

	if direction:
		velocity.x = lerp(velocity.x, direction.x * current_speed, delta * accel_to_use)
		velocity.z = lerp(velocity.z, direction.z * current_speed, delta * accel_to_use)
	else:
		velocity.x = lerp(velocity.x, 0.0, delta * friction_to_use)
		velocity.z = lerp(velocity.z, 0.0, delta * friction_to_use)

	move_and_slide()

	# 5. HEAD BOB & CAMERA EFFECTS
	# Scale bob frequency with speed
	var _bob_speed_multiplier = velocity.length() / SPEED
	t_bob += delta * velocity.length() * float(is_on_floor())
	var bob_pos = _head_bob(t_bob)
	
	# Lean Effect (Tilt camera based on strafing)
	var target_lean = -input_dir.x * LEAN_AMOUNT
	camera_3d.rotation.z = lerp(camera_3d.rotation.z, target_lean, delta * 6.0)

	# Apply Bob + Crouch Height to Camera
	camera_3d.position.y = lerp(camera_3d.position.y, target_cam_y + bob_pos.y, delta * 12.0)
	camera_3d.position.x = lerp(camera_3d.position.x, bob_pos.x, delta * 12.0)

	# 6. FOV SHIFT
	var target_fov = SPRINT_FOV if (Input.is_action_pressed("sprint") and velocity.length() > 2.0) else BASE_FOV
	camera_3d.fov = lerp(camera_3d.fov, target_fov, delta * 8.0)

func _head_bob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos

func _apply_landing_effects():
	# Quick camera dip for impact feel
	camera_3d.position.y -= LANDING_DIP

func _process(_delta):
	if ray_cast_3d.is_colliding():
		collider = ray_cast_3d.get_collider()
		interact_object.emit(collider)
	else: 
		collider = null
		interact_object.emit(null)
