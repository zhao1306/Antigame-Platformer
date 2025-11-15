extends Area2D

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

var animation_tween: Tween
var movement_enabled: bool = false
var move_speed: float = 50.0  # Pixels per second
var move_direction: Vector2 = Vector2.RIGHT  # Default: move right
var sprite_initialized: bool = false

func _ready():
	# Ensure sprite is visible and properly configured
	sprite.visible = true
	sprite.scale = Vector2(1, 1)  # Ensure scale is set
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	
	# Connect body_entered signal
	body_entered.connect(_on_body_entered)
	
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
	if movement_enabled:
		# Simple movement
		global_position += move_direction * move_speed * delta

func set_movement_enabled(enabled: bool):
	movement_enabled = enabled

func _set_frame(frame: int):
	sprite.frame = int(frame)

func _on_body_entered(body: Node2D):
	# Check if it's the player
	if body.is_in_group("player"):
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
			_data.apply_effect(body)
		
		# Spawn particles if available
		if _data and _data.particle_effect:
			var particles = _data.particle_effect.instantiate()
			get_parent().add_child(particles)
			particles.global_position = global_position
		
		# Delete immediately - sound will continue playing independently
		queue_free()
