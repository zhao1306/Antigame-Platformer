extends CharacterBody2D

# Pickup script - handles collection of items

var _data: PickupData
@export var data: PickupData:
	get:
		return _data
	set(value):
		_data = value
		# If already in tree, re-initialize sprite
		if is_inside_tree() and _data:
			call_deferred("_setup_sprite")

@export var hframes: int = 1  # Horizontal frames in spritesheet (set in Inspector)
@export var vframes: int = 1  # Vertical frames in spritesheet (set in Inspector)
@onready var sprite: Sprite2D = $Sprite2D
@onready var collect_sound: AudioStreamPlayer = $CollectSound
@onready var collection_area: Area2D = $CollectionArea

var animation_tween: Tween
var movement_enabled: bool = false
var move_speed: float = 50.0  # Pixels per second
var move_direction: Vector2 = Vector2.RIGHT  # Default: move right
var sprite_initialized: bool = false

# Physics variables (matching player values)
# Note: velocity is inherited from CharacterBody2D, no need to declare it
var gravity_accel: float = 800.0  # Same as player y_acceleration
var terminal_velocity: float = 600.0  # Same as player
var time_manager: Node

func _ready():
	# Initialize velocity
	velocity = Vector2.ZERO
	
	# Configure collision layers (Godot best practice)
	# collision_layer = 0: Pickup is not on any collision layer (player won't collide with it as solid)
	# collision_mask = 1: Pickup will collide with layer 1 (ground/walls)
	collision_layer = 0
	collision_mask = 1
	print("Pickup _ready - collision_layer: ", collision_layer, " collision_mask: ", collision_mask)
	
	# Get time manager for gravity scaling
	time_manager = get_node_or_null("/root/TimeStateManager")
	print("Pickup _ready - time_manager: ", time_manager)
	
	# Ensure sprite is visible and properly configured
	sprite.visible = true
	sprite.scale = Vector2(1, 1)  # Ensure scale is set
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	
	# Connect collection area body_entered signal
	if collection_area:
		collection_area.body_entered.connect(_on_body_entered)
		print("Pickup _ready - CollectionArea connected")
	else:
		print("WARNING: CollectionArea not found! Pickup collection may not work.")
	
	# Debug: Check collision shape
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape:
		print("Pickup _ready - CollisionShape2D found: ", collision_shape.shape)
	else:
		print("WARNING: CollisionShape2D not found! Physics may not work.")
	
	# Sync _data from the actual export property (in case setter didn't fire when loading from scene)
	# This handles the case where scene is loaded with data already set
	# Use get() to access the raw property value without triggering getter
	var exported_data = get("data")
	if not _data and exported_data:
		_data = exported_data
	
	# Setup sprite if data is already set
	if _data:
		_setup_sprite()

func _setup_sprite():
	if sprite_initialized:
		return  # Already initialized
	
	if not _data:
		return
	
	if not _data.texture:
		return
	
	# Get texture path for checking BEFORE setting texture
	var texture_path = ""
	if _data.texture.has_method("get_path"):
		texture_path = _data.texture.get_path()
	elif _data.texture.resource_path:
		texture_path = _data.texture.resource_path
	else:
		texture_path = str(_data.texture)
	
	# Auto-set frame counts based on pickup type (can be overridden in Inspector)
	if hframes == 1 and vframes == 1:  # Only auto-set if using defaults
		if "Coin" in texture_path or _data is CoinData:
			hframes = 6
			vframes = 1
		elif "1_Up" in texture_path or _data is DrugPowerupData:
			hframes = 16
			vframes = 1
	
	# Set sprite frames BEFORE setting texture
	sprite.hframes = hframes
	sprite.vframes = vframes
	sprite.frame = 0
	
	# Now set the texture
	sprite.texture = _data.texture
	
	if not sprite.texture:
		return
	
	# Use configured frame counts (set in Inspector or auto-detected above)
	var total_frames = hframes * vframes
	
	# Stop any existing animation
	if animation_tween:
		animation_tween.kill()
		animation_tween = null
	
	# Animate if multiple frames
	if total_frames > 1:
		animation_tween = create_tween()
		animation_tween.set_loops()
		var anim_duration = total_frames * 0.1  # ~10 FPS
		animation_tween.tween_method(_set_frame, 0, total_frames - 1, anim_duration)
	
	sprite_initialized = true

func _physics_process(delta):
	if not movement_enabled:
		return
	
	# Get time scale (same as player)
	var time_scale = time_manager.get_time_scale() if time_manager else 1.0
	var accel_scale = pow(time_scale, 2)  # Maintain distance when time stretches
	var effective_gravity = gravity_accel * accel_scale * 0.4
	var scaled_terminal_velocity = terminal_velocity * time_scale
	var scaled_move_speed = move_speed * time_scale

	
	# Apply gravity only if not on ground
	if not is_on_floor():
		velocity.y += effective_gravity * delta
		velocity.y = min(velocity.y, scaled_terminal_velocity)
	else:
		# Stop falling when on ground
		if velocity.y > 0:
			velocity.y = 0
	
	# Horizontal movement
	velocity.x = move_direction.x * scaled_move_speed
	
	# Use move_and_slide() for proper collision handling (Godot best practice)
	move_and_slide()
	
	# Check ALL collisions after movement for player contact
	# This handles collisions from any direction (walls, floors, ceilings)
	var collision_count = get_slide_collision_count()
	var hit_player = false
	
	for i in range(collision_count):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Check if collider is a player
		if collider and collider.is_in_group("player"):
			hit_player = true
			_collect_pickup(collider)
			return  # Exit immediately since we're collecting
	
	# Only handle wall collisions if we didn't hit a player
	if is_on_wall() and not hit_player:
		move_direction.x *= -1

func set_movement_enabled(enabled: bool):
	movement_enabled = enabled
	print("Pickup movement_enabled set to: ", enabled, " at position: ", global_position)

func _set_frame(frame: int):
	sprite.frame = int(frame)

func _on_body_entered(body: Node2D):
	# Check if it's the player
	if body.is_in_group("player"):
		print("Pickup collected via Area2D detection")
		_collect_pickup(body)

func _collect_pickup(player: Node2D):
	# Stop animation immediately
	if animation_tween:
		animation_tween.kill()
		animation_tween = null
	
	# Hide sprite immediately
	sprite.visible = false
	
	# Play collection sound - reparent to scene root so it can finish playing
	if collect_sound:
		var sound_to_play: AudioStreamPlayer2D = null
		if _data is CoinData:
			var coin_sound = load("res://Assets (Little Runmo)/8_Music_Sound Effects/Coin.wav")
			if coin_sound:
				sound_to_play = AudioStreamPlayer2D.new()
				sound_to_play.stream = coin_sound
				get_tree().root.add_child(sound_to_play)
				sound_to_play.global_position = global_position
				sound_to_play.play()
				# Auto-delete sound player when finished
				sound_to_play.finished.connect(func(): sound_to_play.queue_free())
		elif _data is DrugPowerupData:
			var powerup_sound = load("res://Assets (Little Runmo)/8_Music_Sound Effects/1up.wav")
			if powerup_sound:
				sound_to_play = AudioStreamPlayer2D.new()
				sound_to_play.stream = powerup_sound
				get_tree().root.add_child(sound_to_play)
				sound_to_play.global_position = global_position
				sound_to_play.play()
				# Auto-delete sound player when finished
				sound_to_play.finished.connect(func(): sound_to_play.queue_free())
	
	# Apply the effect
	if _data:
		_data.apply_effect(player)
	
	# Spawn particles if available
	if _data and _data.particle_effect:
		var particles = _data.particle_effect.instantiate()
		get_parent().add_child(particles)
		particles.global_position = global_position
	
	# Delete immediately - sound will continue playing independently
	queue_free()
