extends CharacterBody2D

# --- Movement Settings ---
@export_category("Movement")
## The max speed your player will move (base speed, scales with time state)
@export_range(50, 500) var max_speed: float = 200.0
## How fast your player will reach max speed from rest (in seconds)
@export_range(0, 4) var time_to_reach_max_speed: float = 0.2
## How fast your player will reach zero speed from max speed (in seconds)
@export_range(0, 4) var time_to_reach_zero_speed: float = 0.2
## If true, player will instantly move and switch directions
@export var directional_snap: bool = false

# --- Jumping and Gravity ---
@export_category("Jumping and Gravity")
## The peak height of your player's jump (in pixels)
@export_range(0, 200) var jump_height: float = 200.0
## The strength at which your character will be pulled to the ground (base gravity in pixels/sec²)
@export_range(0, 2000) var gravity_scale: float = 600.0
## The fastest your player can fall
@export_range(0, 1000) var terminal_velocity: float = 500.0
## Your player will move this amount faster when falling
@export_range(0.5, 3) var descending_gravity_factor: float = 1
## Enabling this makes jump height variable based on how long you hold jump
@export var variable_jump_height: bool = true
## How much the jump height is cut by when releasing early
@export_range(1, 10) var jump_variable: float = 2
## Extra time (in seconds) to jump after falling off an edge
@export_range(0, 0.5) var coyote_time: float = 0.2
## Window of time (in seconds) to press jump before landing and still jump
@export_range(0, 0.5) var jump_buffering: float = 0.2

# --- Internal Variables ---
var time_manager: Node  # Reference to TimeStateManager (autoload)
var base_gravity: float
var current_max_speed: float
var acceleration: float
var deceleration: float
var jump_acceleration: float  # Jump force applied while jump key is held
var applied_gravity: float
var applied_terminal_velocity: float

# Momentum conservation
var previous_time_scale: float = 1.0

# Jump state
var jump_was_pressed: bool = false
var coyote_active: bool = false
var jump_count: int = 1
var is_jumping: bool = false  # True while jump key is held and we're ascending

func _ready():
	print("Player script loaded! jump_count initialized to: ", jump_count)
	
	# Get time manager from autoload
	time_manager = get_node("/root/TimeStateManager")
	
	# Connect to time state changes
	if time_manager:
		time_manager.time_state_changed.connect(_on_time_state_changed)
		previous_time_scale = time_manager.get_time_scale()
	
	# Get base gravity from project settings
	base_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	
	# Initialize terminal velocity
	applied_terminal_velocity = terminal_velocity
	
	# Calculate derived values
	_update_movement_data()
	
	print("Jump acceleration calculated: ", jump_acceleration)

func _update_movement_data():
	# Calculate acceleration/deceleration based on time to reach speeds
	if time_to_reach_max_speed > 0:
		acceleration = max_speed / time_to_reach_max_speed
	else:
		acceleration = max_speed * 1000  # Very fast if 0
	
	if time_to_reach_zero_speed > 0:
		deceleration = max_speed / time_to_reach_zero_speed
	else:
		deceleration = max_speed * 1000  # Very fast if 0
	
	# Calculate jump acceleration based on desired jump height
	# Jump acceleration should overcome gravity to reach jump_height
	# Using: h = (v²)/(2g), and v = a*t, where a is net acceleration (jump_accel - gravity)
	# For simplicity, set jump acceleration to be strong enough to reach jump_height
	# A good rule: jump_acceleration should be significantly higher than gravity
	jump_acceleration = gravity_scale * 2.5  # Adjust multiplier to control jump feel
	
	# Update current max speed based on time scale
	_update_max_speed()

func _update_max_speed():
	# Max speed does NOT scale with time_scale - only acceleration scales
	# This ensures consistent distance traveled across time states
	current_max_speed = max_speed

func _on_time_state_changed(_new_state: int):
	# Conserve horizontal momentum when time state changes
	# The velocity.x stays the same - this is the "cheese" mechanic!
	# World physics (gravity, etc.) will scale, but player momentum is conserved
	previous_time_scale = time_manager.get_time_scale() if time_manager else 1.0
	
	# Update max speed for new time scale
	_update_max_speed()
	
	# Note: velocity.x is NOT modified - momentum is conserved!
	# The movement speed cap changes, but current velocity remains

func _physics_process(delta):
	# Get current time scale
	var time_scale = 1.0
	if time_manager:
		time_scale = time_manager.get_time_scale()
		# Update max speed if time scale changed
		if abs(time_scale - previous_time_scale) > 0.01:
			_update_max_speed()
			previous_time_scale = time_scale
	
	# Scale delta by time scale (world physics scale with time)
	var scaled_delta = delta * time_scale
	
	# --- Input Detection ---
	var left_hold = Input.is_action_pressed("ui_left")
	var right_hold = Input.is_action_pressed("ui_right")
	# Try multiple input actions for jump (ui_accept is space/enter, ui_up is up arrow)
	var jump_tap = Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")
	var jump_hold = Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up")
	var jump_release = Input.is_action_just_released("ui_accept") or Input.is_action_just_released("ui_up")
	
	# Debug: Check if input is being detected
	if jump_tap:
		print("Jump input detected! jump_count: ", jump_count, " is_on_floor(): ", is_on_floor())
	
	# Debug controls for time state (J = slow, K = fast)
	# Note: These are handled in TimeStateManager._input() now
	
	# --- Horizontal Movement with Momentum Gathering ---
	var direction = 0.0
	if right_hold:
		direction = 1.0
	elif left_hold:
		direction = -1.0
	
	# Momentum gathering - acceleration scales with time_scale, but max speed does not
	# On ground: clamp to max speed (don't retain momentum above cap)
	# In air: retain momentum (don't clamp)
	if direction != 0.0:
		if direction > 0:  # Moving right
			if directional_snap:
				velocity.x = current_max_speed
			else:
				# Scale acceleration by time_scale (but max speed stays constant)
				velocity.x += acceleration * scaled_delta
				# Clamp to max speed only if on ground
				if is_on_floor():
					velocity.x = min(velocity.x, current_max_speed)
		else:  # Moving left
			if directional_snap:
				velocity.x = -current_max_speed
			else:
				# Scale acceleration by time_scale (but max speed stays constant)
				velocity.x -= acceleration * scaled_delta
				# Clamp to max speed only if on ground
				if is_on_floor():
					velocity.x = max(velocity.x, -current_max_speed)
	else:
		# No input - retain momentum in air, decelerate on ground
		if is_on_floor():
			# On ground: clamp to max speed and decelerate
			if not directional_snap:
				_decelerate(scaled_delta)
				# Clamp to max speed after deceleration
				if velocity.x > current_max_speed:
					velocity.x = current_max_speed
				elif velocity.x < -current_max_speed:
					velocity.x = -current_max_speed
			else:
				velocity.x = 0
		# In air: momentum is retained (no deceleration, no clamping) - this is the key mechanic!
	
	# --- Gravity (scales with time state) ---
	if velocity.y > 0:
		applied_gravity = gravity_scale * descending_gravity_factor
	else:
		applied_gravity = gravity_scale
	
	# Apply gravity (scaled by time state)
	if not is_on_floor():
		if velocity.y < applied_terminal_velocity:
			velocity.y += applied_gravity * scaled_delta
		elif velocity.y > applied_terminal_velocity:
			velocity.y = applied_terminal_velocity
	else:
		applied_terminal_velocity = terminal_velocity
	
	# --- Jumping (as acceleration) ---
	# Jump has two parts:
	# 1. Initial velocity boost (scaled by sqrt(time_scale) for consistent height)
	# 2. Continuous acceleration while held (scales with time_scale)
	
	# Check if we can start a jump (must be on floor)
	if jump_tap and is_on_floor() and jump_count > 0:
		is_jumping = true
		jump_count = 0
		
		# Give initial velocity boost to get off the ground
		# Scale by sqrt(time_scale) so jump height is consistent across time states
		# This compensates for gravity scaling with time_scale
		var initial_jump_velocity = sqrt(2.0 * gravity_scale * jump_height) * sqrt(time_scale)
		velocity.y = -initial_jump_velocity
		print("Jump started! Initial velocity: ", -initial_jump_velocity, " (time_scale: ", time_scale, ")")
	
	# Apply jump acceleration while jump key is held
	# Only apply while ascending (velocity.y < 0) to prevent jumping while falling
	if is_jumping and jump_hold and velocity.y < 0:
		# Apply jump acceleration (scales with time_scale)
		# Net acceleration = jump_acceleration - gravity (both scale with time_scale)
		velocity.y -= jump_acceleration * scaled_delta
	
	# Stop jumping when jump key is released or we start falling
	if jump_release or velocity.y >= 0:
		is_jumping = false
	
	# Reset jump count when on floor
	if is_on_floor():
		jump_count = 1
		is_jumping = false
		coyote_active = false
		jump_was_pressed = false
		
		# On ground: instantly clamp velocity to max speed cap
		# This ensures momentum above cap is lost when landing
		if velocity.x > current_max_speed:
			velocity.x = current_max_speed
		elif velocity.x < -current_max_speed:
			velocity.x = -current_max_speed
	
	# Move the player
	move_and_slide()

func _decelerate(delta: float):
	# Decelerate horizontally
	if abs(velocity.x) > 0:
		if abs(velocity.x) <= abs(deceleration * delta):
			velocity.x = 0
		elif velocity.x > 0:
			velocity.x -= deceleration * delta
		elif velocity.x < 0:
			velocity.x += deceleration * delta

# Jump is now handled as continuous acceleration in _physics_process
# No need for _jump() function anymore

func _coyote_time_timer():
	await get_tree().create_timer(coyote_time).timeout
	coyote_active = false
	jump_count = 0

func _buffer_jump_timer():
	await get_tree().create_timer(jump_buffering).timeout
	jump_was_pressed = false
