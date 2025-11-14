extends CharacterBody2D

# === EXPORT VARIABLES ===
@export_category("Movement")
@export_range(50, 500) var max_speed: float = 200.0
@export_range(100, 5000) var x_acceleration: float = 1500.0  # Horizontal acceleration (pixels/sec²)
@export_range(100, 5000) var x_friction: float = 1200.0  # Ground friction

@export_category("Jumping and Gravity")
@export_range(100, 1000) var jump_height: float = 200.0  # Target jump height (pixels)
@export_range(100, 3000) var gravity: float = 800.0  # Downward gravity force (pixels/sec²)
@export_range(100, 2000) var terminal_velocity: float = 600.0
@export_range(0.5, 3) var gravity_fall_multiplier: float = 1.5  # Gravity stronger when falling

# === INTERNAL VARIABLES ===
var time_manager: Node
var jump_velocity: float  # Calculated from jump_height

func _ready():
	time_manager = get_node("/root/TimeStateManager")
	
	# Calculate jump velocity from desired height using physics:
	# At peak: v = 0, height h = v₀²/(2g)
	# Therefore: v₀ = sqrt(2×g×h)
	jump_velocity = sqrt(2.0 * gravity * jump_height)
	
	print("Player ready! Jump velocity: ", jump_velocity, " for height: ", jump_height)

func _physics_process(delta):
	# Get time scale
	var time_scale = time_manager.get_time_scale() if time_manager else 1.0
	var scaled_delta = delta * time_scale
	
	# Scaled values
	var scaled_max_speed = max_speed * time_scale
	var scaled_terminal_velocity = terminal_velocity * time_scale
	# Jump velocity NOT scaled - this is the key to consistent height
	
	# === INPUT ===
	var move_input = Input.get_axis("ui_left", "ui_right")
	var jump_pressed = Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")
	
	# === HORIZONTAL ACCELERATION ===
	if move_input != 0:
		# Horizontal acceleration uses BASE delta for consistent feel
		velocity.x += move_input * x_acceleration * delta
		velocity.x = clamp(velocity.x, -scaled_max_speed, scaled_max_speed)
	else:
		if is_on_floor():
			# Friction uses BASE delta
			var friction_force = x_friction * delta
			if abs(velocity.x) <= friction_force:
				velocity.x = 0
			else:
				velocity.x -= sign(velocity.x) * friction_force
	
	# === GRAVITY ===
	if not is_on_floor():
		var gravity_force = gravity
		if velocity.y > 0:  # Falling
			gravity_force *= gravity_fall_multiplier
		
		# Gravity uses BASE delta (not scaled) for consistent jump height
		velocity.y += gravity_force * delta
		velocity.y = min(velocity.y, scaled_terminal_velocity)
	
	# === JUMPING ===
	# Set velocity directly (UNSCALED for consistent height across time states)
	if jump_pressed and is_on_floor():
		velocity.y = -jump_velocity
		print("Jump! velocity.y = ", velocity.y)
	
	# === MOVE ===
	move_and_slide()
