extends CharacterBody2D

# === EXPORT VARIABLES ===
@export_category("Movement")
@export_range(50, 500) var max_speed: float = 200.0
@export_range(100, 5000) var x_acceleration: float = 1500.0  # Base horizontal acceleration (px/s²)

@export_category("Jumping and Gravity")
@export_range(100, 5000) var jump_height: float = 375.0        # Desired jump apex height (px)
@export_range(100, 3000) var y_acceleration: float = 800.0    # Base vertical acceleration (px/s²)

# === INTERNAL VARIABLES ===
var time_manager: Node
var coin_count: int = 0
var powerup_timer: Timer = null  # Track active power-up timer
var is_powerup_active: bool = false  # Track if power-up is currently active
# UIManager is now an autoload singleton - access via get_node("/root/UIManager")

func _ready():
	time_manager = get_node("/root/TimeStateManager")
	# UIManager is now an autoload singleton - no need to find it

func _physics_process(delta):
	# Get time scale
	var time_scale = time_manager.get_time_scale() if time_manager else 1.0
	var accel_scale = pow(time_scale, 2)  # Maintain distance when time stretches	
	# Scaled values
	var scaled_max_speed = max_speed * time_scale
	var effective_x_accel = x_acceleration * accel_scale
	var effective_y_accel = y_acceleration * accel_scale
	# Scale drag factors by time_scale to maintain same effect over real-world time
	# drag^time_scale ensures same total drag effect regardless of time scale
	var base_x_drag = 0.91
	var base_y_drag = 0.98
	var effective_x_drag = pow(base_x_drag, time_scale)
	var effective_y_drag = pow(base_y_drag, time_scale)
	
	# Clamp velocity to new max speed when time scale changes
	if is_on_floor():
		velocity.x = clamp(velocity.x, -scaled_max_speed, scaled_max_speed)
	
	# === INPUT ===
	var move_input = Input.get_axis("ui_left", "ui_right")
	var jump_pressed = Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")
	
	# === HORIZONTAL ACCELERATION ===
	if move_input != 0:
		var same_direction = (move_input > 0 and velocity.x >= 0) or (move_input < 0 and velocity.x <= 0)
		var can_accelerate = true
		if same_direction and abs(velocity.x) >= scaled_max_speed:
			can_accelerate = false
		
		if can_accelerate:
			velocity.x += move_input * effective_x_accel * delta
	else:
		if is_on_floor():
			velocity.x *= effective_x_drag * 0.6
		else:
			velocity.x *= effective_x_drag
	
	# === GRAVITY ===
	if not is_on_floor():
		velocity.y += effective_y_accel * delta
		velocity.y *= effective_y_drag
	
	# === JUMPING ===
	if jump_pressed and is_on_floor():
		var scaled_jump_height = jump_height * time_scale
		velocity.y = -scaled_jump_height
		
	
	# === MOVE ===
	move_and_slide()

# Add coins to player
func add_coin(amount: int):
	coin_count += amount
	print("Coin collected! Total: ", coin_count)
	# Update UI counter
	var ui_manager = get_node("/root/UIManager")
	if ui_manager:
		ui_manager.update_coin_counter(coin_count)

# Start power-up transition sequence
func start_powerup_transition():
	var ui_manager = get_node("/root/UIManager")
	
	# If power-up is already active, just extend the timer
	if is_powerup_active:
		print("Power-up already active, extending timer")
		# Cancel existing timer
		if powerup_timer:
			powerup_timer.queue_free()
			powerup_timer = null
		# Start new 8-second timer
		_start_powerup_timer()
		return
	
	# First time entering power-up state
	print("Power-up transition started")
	is_powerup_active = true
	
	# Freeze player
	set_physics_process(false)
	
	# Play flicker animation
	if ui_manager:
		await ui_manager.play_powerup_flicker()
	
	# Set power-up state
	if time_manager:
		time_manager.set_state(TimeStateManager.TimeState.POWERUP)
	
	# Unfreeze player
	set_physics_process(true)
	print("Power-up transition complete")
	
	# Start the 8-second timer
	_start_powerup_timer()

func _start_powerup_timer():
	# Create and start 8-second timer
	powerup_timer = Timer.new()
	powerup_timer.wait_time = 8.0
	powerup_timer.one_shot = true
	powerup_timer.timeout.connect(_on_powerup_timer_expired)
	add_child(powerup_timer)
	powerup_timer.start()
	print("Power-up timer started (8 seconds)")

func _on_powerup_timer_expired():
	print("Power-up duration complete, transitioning back")
	is_powerup_active = false
	powerup_timer = null
	
	# Freeze player during exit transition
	set_physics_process(false)
	
	# Play exit flicker animation
	var ui_manager = get_node("/root/UIManager")
	if ui_manager:
		await ui_manager.play_powerup_exit_flicker()
	
	# Return to FAST state
	if time_manager:
		time_manager.set_state(TimeStateManager.TimeState.FAST)
	
	# Unfreeze player
	set_physics_process(true)
	print("Power-up exit transition complete")