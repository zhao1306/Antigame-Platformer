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
## The peak height of your player's jump
@export_range(0, 20) var jump_height: float = 2.0
## The strength at which your character will be pulled to the ground (base gravity)
@export_range(0, 100) var gravity_scale: float = 20.0
## The fastest your player can fall
@export_range(0, 1000) var terminal_velocity: float = 500.0
## Your player will move this amount faster when falling
@export_range(0.5, 3) var descending_gravity_factor: float = 1.3
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
var jump_magnitude: float
var applied_gravity: float
var applied_terminal_velocity: float

# Momentum conservation
var previous_time_scale: float = 1.0

# Jump state
var jump_was_pressed: bool = false
var coyote_active: bool = false
var jump_count: int = 1

func _ready():
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
	
	# Calculate jump magnitude
	jump_magnitude = (10.0 * jump_height) * gravity_scale
	
	# Update current max speed based on time scale
	_update_max_speed()

func _update_max_speed():
	# Max speed scales with time state
	if time_manager:
		var time_scale = time_manager.get_time_scale()
		current_max_speed = max_speed * time_scale
	else:
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
	var jump_tap = Input.is_action_just_pressed("ui_accept")
	var jump_release = Input.is_action_just_released("ui_accept")
	
	# Debug controls for time state (J = slow, K = fast)
	# Note: These are handled in TimeStateManager._input() now
	
	# --- Horizontal Movement with Momentum Gathering ---
	var direction = 0.0
	if right_hold:
		direction = 1.0
	elif left_hold:
		direction = -1.0
	
	# Momentum gathering - only accelerate if below max speed
	# Acceleration uses base delta (consistent feel), but cap scales with time state
	if direction != 0.0:
		if direction > 0:  # Moving right
			if velocity.x < current_max_speed or directional_snap:
				if directional_snap:
					velocity.x = current_max_speed
				else:
					# Acceleration uses base delta for consistent feel
					velocity.x += acceleration * delta
					velocity.x = min(velocity.x, current_max_speed)
			# If already at or above max speed, momentum is retained
		else:  # Moving left
			if velocity.x > -current_max_speed or directional_snap:
				if directional_snap:
					velocity.x = -current_max_speed
				else:
					# Acceleration uses base delta for consistent feel
					velocity.x -= acceleration * delta
					velocity.x = max(velocity.x, -current_max_speed)
			# If already at or above max speed, momentum is retained
	else:
		# No input - retain momentum in air, decelerate on ground
		if is_on_floor():
			# Decelerate on ground (uses base delta for consistent feel)
			if not directional_snap:
				_decelerate(delta)
			else:
				velocity.x = 0
		# In air: momentum is retained (no deceleration) - this is the key mechanic!
	
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
	
	# Variable jump height
	if variable_jump_height and jump_release and velocity.y < 0:
		velocity.y = velocity.y / jump_variable
	
	# --- Jumping with Coyote Time and Buffering ---
	if jump_count == 1:  # Single jump mode (with coyote time and buffering)
		if not is_on_floor():
			if coyote_time > 0:
				coyote_active = true
				_coyote_time_timer()
		
		if jump_tap:
			if coyote_active:
				coyote_active = false
				_jump()
			elif jump_buffering > 0:
				jump_was_pressed = true
				_buffer_jump_timer()
			elif is_on_floor():
				_jump()
		
		if is_on_floor():
			if coyote_time > 0:
				coyote_active = true
			else:
				coyote_active = false
			if jump_was_pressed:
				_jump()
	
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

func _jump():
	velocity.y = -jump_magnitude
	jump_was_pressed = false
	jump_count = 0

func _coyote_time_timer():
	await get_tree().create_timer(coyote_time).timeout
	coyote_active = false
	jump_count = 0

func _buffer_jump_timer():
	await get_tree().create_timer(jump_buffering).timeout
	jump_was_pressed = false
