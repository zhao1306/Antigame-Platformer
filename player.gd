extends CharacterBody2D

# === EXPORT VARIABLES ===
@export_category("Movement")
@export_range(50, 500) var max_speed: float = 200.0
@export_range(100, 5000) var x_acceleration: float = 1500.0  # Base horizontal acceleration (px/s²)

@export_category("Jumping and Gravity")
@export_range(100, 5000) var jump_height: float = 350.0        # Desired jump apex height (px)
@export_range(100, 3000) var y_acceleration: float = 800.0    # Base vertical acceleration (px/s²)
@export_range(100, 2000) var terminal_velocity: float = 600.0

# === INTERNAL VARIABLES ===
var time_manager: Node
var coin_count: int = 0
var ui_manager: Node

func _ready():
	time_manager = get_node("/root/TimeStateManager")
	ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if not ui_manager:
		# Try to find UI node
		var main_scene = get_tree().root.get_child(0)
		ui_manager = main_scene.get_node_or_null("UI")
		if ui_manager:
			ui_manager.add_to_group("ui_manager")
	
	print("Player ready! jump_height=", jump_height, " y_accel=", y_acceleration)

func _physics_process(delta):
	# Get time scale
	var time_scale = time_manager.get_time_scale() if time_manager else 1.0
	var accel_scale = pow(time_scale, 2)  # Maintain distance when time stretches	
	# Scaled values
	var scaled_max_speed = max_speed * time_scale
	var scaled_terminal_velocity = terminal_velocity * time_scale
	var effective_x_accel = x_acceleration * accel_scale
	var effective_y_accel = y_acceleration * accel_scale
	var effective_x_drag = 0.91
	
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
		velocity.y = min(velocity.y, scaled_terminal_velocity)
	
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
	if ui_manager and ui_manager.has_method("update_coin_counter"):
		ui_manager.update_coin_counter(coin_count)

# Start power-up transition sequence
func start_powerup_transition():
	print("Power-up transition started")
	# Freeze player
	set_physics_process(false)
	
	# Play flicker animation
	if ui_manager and ui_manager.has_method("play_powerup_flicker"):
		await ui_manager.play_powerup_flicker()
	
	# Set power-up state
	if time_manager:
		time_manager.set_state(TimeStateManager.TimeState.POWERUP)
	
	# Unfreeze player
	set_physics_process(true)
	print("Power-up transition complete")
