extends CharacterBody2D

## === EXPORT VARIABLES ===
@export_category("Movement")
@export_range(50, 500) var max_speed: float = 200.0
@export_range(100, 5000) var x_acceleration: float = 1500.0

@export_category("Jumping and Gravity")
@export_range(100, 5000) var jump_height: float = 375.0
@export_range(100, 3000) var y_acceleration: float = 800.0

## === CONSTANTS ===
const AGE_YOUNG_THRESHOLD: int = 40
const AGE_MEDIUM_THRESHOLD: int = 65
const AGE_TIMER_INTERVAL: float = 30.0
const POWERUP_DURATION: float = 8.0
const MOVEMENT_THRESHOLD: float = 10.0
const ANIMATION_SPEED: float = 0.2
const BASE_X_DRAG: float = 0.91
const BASE_Y_DRAG: float = 0.98
const FLOOR_DRAG_MULTIPLIER: float = 0.6

## Animation frame indices
const FRAME_WALK_LEFT_0: int = 0
const FRAME_WALK_LEFT_1: int = 1
const FRAME_WALK_LEFT_2: int = 2
const FRAME_WALK_RIGHT_0: int = 3
const FRAME_WALK_RIGHT_1: int = 4
const FRAME_WALK_RIGHT_2: int = 5
const FRAME_IDLE_LEFT: int = 6
const FRAME_IDLE_RIGHT: int = 7
const FRAME_JUMP_RIGHT: int = 8

## === NODE REFERENCES ===
@onready var sprite: Sprite2D = $Sprite2D

## === AUTOLOAD REFERENCES ===
var time_manager: TimeStateManager
var ui_manager: Node

## === GAME STATE ===
var coin_count: int = 0
var age: int = 0
var facing_right: bool = true

## === POWER-UP SYSTEM ===
var powerup_timer: Timer = null
var is_powerup_active: bool = false

## === AGE SYSTEM ===
var age_timer: Timer = null
var young_texture: Texture2D = load("res://Assets (Little Runmo)/young_age.png")
var med_texture: Texture2D = load("res://Assets (Little Runmo)/med_age_.png")
var old_texture: Texture2D = load("res://Assets (Little Runmo)/old_age.png")

## === ANIMATION SYSTEM ===
var animation_timer: float = 0.0
var current_animation_frame: int = FRAME_IDLE_RIGHT
var walk_cycle_direction: int = 1  # 1 for forward (0→1→2), -1 for backward (2→1→0)

## === LIFECYCLE ===
func _ready() -> void:
	time_manager = get_node("/root/TimeStateManager")
	ui_manager = get_node("/root/UIManager")
	
	if not sprite:
		push_error("Sprite2D node not found!")
		return
	
	_initialize_age_system()
	_update_age_sprite()

func _physics_process(delta: float) -> void:
	var time_scale: float = time_manager.get_time_scale() if time_manager else 1.0
	var accel_scale: float = pow(time_scale, 2)
	
	# Calculate scaled values
	var scaled_max_speed: float = max_speed * time_scale
	var effective_x_accel: float = x_acceleration * accel_scale
	var effective_y_accel: float = y_acceleration * accel_scale
	var effective_x_drag: float = pow(BASE_X_DRAG, time_scale)
	var effective_y_drag: float = pow(BASE_Y_DRAG, time_scale)
	
	# Clamp velocity when on floor
	if is_on_floor():
		velocity.x = clamp(velocity.x, -scaled_max_speed, scaled_max_speed)
	
	# Process input
	var move_input: float = Input.get_axis("ui_left", "ui_right")
	var jump_pressed: bool = Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")
	
	# Update facing direction based on input
	if move_input != 0:
		facing_right = move_input > 0
	
	# Apply horizontal movement
	_apply_horizontal_movement(move_input, effective_x_accel, effective_x_drag, scaled_max_speed, delta)
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += effective_y_accel * delta
		velocity.y *= effective_y_drag
	
	# Handle jumping
	if jump_pressed and is_on_floor():
		velocity.y = -jump_height * time_scale
	
	# Update animation
	_update_animation(delta)
	
	# Move the character
	move_and_slide()

## === MOVEMENT ===
func _apply_horizontal_movement(move_input: float, accel: float, drag: float, max_speed: float, delta: float) -> void:
	if move_input != 0:
		var same_direction: bool = (move_input > 0 and velocity.x >= 0) or (move_input < 0 and velocity.x <= 0)
		var can_accelerate: bool = not (same_direction and abs(velocity.x) >= max_speed)
		
		if can_accelerate:
			velocity.x += move_input * accel * delta
	else:
		var drag_multiplier: float = FLOOR_DRAG_MULTIPLIER if is_on_floor() else 1.0
		velocity.x *= drag * drag_multiplier

## === COIN SYSTEM ===
func add_coin(amount: int) -> void:
	coin_count += amount
	age += amount
	_update_age_sprite()
	
	if ui_manager:
		ui_manager.update_coin_counter(coin_count)

## === POWER-UP SYSTEM ===
func start_powerup_transition() -> void:
	if is_powerup_active:
		_extend_powerup_timer()
		return
	
	is_powerup_active = true
	set_physics_process(false)
	
	if ui_manager:
		await ui_manager.play_powerup_flicker()
	
	if time_manager:
		time_manager.set_state(TimeStateManager.TimeState.POWERUP)
	
	set_physics_process(true)
	_start_powerup_timer()

func _extend_powerup_timer() -> void:
	if powerup_timer:
		powerup_timer.queue_free()
		powerup_timer = null
	_start_powerup_timer()

func _start_powerup_timer() -> void:
	powerup_timer = Timer.new()
	powerup_timer.wait_time = POWERUP_DURATION
	powerup_timer.one_shot = true
	powerup_timer.timeout.connect(_on_powerup_timer_expired)
	add_child(powerup_timer)
	powerup_timer.start()

func _on_powerup_timer_expired() -> void:
	is_powerup_active = false
	powerup_timer = null
	
	set_physics_process(false)
	
	if ui_manager:
		await ui_manager.play_powerup_exit_flicker()
	
	if time_manager:
		time_manager.set_state(TimeStateManager.TimeState.FAST)
	
	set_physics_process(true)

## === AGE SYSTEM ===
func _initialize_age_system() -> void:
	age_timer = Timer.new()
	age_timer.wait_time = AGE_TIMER_INTERVAL
	age_timer.timeout.connect(_on_age_timer_timeout)
	add_child(age_timer)
	age_timer.start()

func _on_age_timer_timeout() -> void:
	age += 1
	_update_age_sprite()

func _update_age_sprite() -> void:
	if not sprite:
		return
	
	var texture_to_use: Texture2D
	if age < AGE_YOUNG_THRESHOLD:
		texture_to_use = young_texture
	elif age < AGE_MEDIUM_THRESHOLD:
		texture_to_use = med_texture
	else:
		texture_to_use = old_texture
	
	if sprite.texture != texture_to_use:
		sprite.texture = texture_to_use

## === ANIMATION SYSTEM ===
func _update_animation(delta: float) -> void:
	if not sprite:
		return
	
	animation_timer += delta
	
	var is_moving: bool = abs(velocity.x) > MOVEMENT_THRESHOLD
	var is_jumping: bool = not is_on_floor()
	
	if is_jumping:
		_handle_jump_animation()
	elif is_moving:
		_handle_walk_animation()
	else:
		_handle_idle_animation()
	
	sprite.frame = current_animation_frame

func _handle_jump_animation() -> void:
	current_animation_frame = FRAME_JUMP_RIGHT
	sprite.flip_h = not facing_right
	animation_timer = 0.0

func _handle_walk_animation() -> void:
	if facing_right:
		_cycle_walk_frames(FRAME_WALK_RIGHT_0, FRAME_WALK_RIGHT_1, FRAME_WALK_RIGHT_2)
	else:
		_cycle_walk_frames(FRAME_WALK_LEFT_0, FRAME_WALK_LEFT_1, FRAME_WALK_LEFT_2)
	sprite.flip_h = false

func _cycle_walk_frames(frame0: int, frame1: int, frame2: int) -> void:
	# Initialize to first frame if not in walk cycle
	if current_animation_frame < frame0 or current_animation_frame > frame2:
		current_animation_frame = frame0
		walk_cycle_direction = 1
	
	# Cycle: 0→1→2→1→0→1→2→1...
	if animation_timer >= ANIMATION_SPEED:
		animation_timer = 0.0
		if current_animation_frame == frame0:
			current_animation_frame = frame1
			walk_cycle_direction = 1
		elif current_animation_frame == frame1:
			if walk_cycle_direction == 1:
				current_animation_frame = frame2
			else:
				current_animation_frame = frame0
		elif current_animation_frame == frame2:
			current_animation_frame = frame1
			walk_cycle_direction = -1

func _handle_idle_animation() -> void:
	current_animation_frame = FRAME_IDLE_RIGHT if facing_right else FRAME_IDLE_LEFT
	sprite.flip_h = false
	animation_timer = 0.0
