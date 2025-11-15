extends Area2D

# Pickup script - handles collection of items

@export var data: PickupData
@export var hframes: int = 1  # Horizontal frames in spritesheet (set in Inspector)
@export var vframes: int = 1  # Vertical frames in spritesheet (set in Inspector)
@onready var sprite: Sprite2D = $Sprite2D
@onready var collect_sound: AudioStreamPlayer = $CollectSound

var animation_tween: Tween

func _ready():
	# Ensure sprite is visible and properly configured
	sprite.visible = true
	sprite.scale = Vector2(1, 1)  # Ensure scale is set
	
	# Set sprite texture from data
	if not data:
		print("Pickup: ERROR - data is null!")
		return
	
	if not data.texture:
		print("Pickup: ERROR - data.texture is null! Data type: ", data.get_script().get_path())
		return
	
	sprite.texture = data.texture
	
	if not sprite.texture:
		print("Pickup: ERROR - sprite.texture is null after assignment!")
		return
	
	# Get texture path for checking
	var texture_path = ""
	if data.texture.has_method("get_path"):
		texture_path = data.texture.get_path()
	elif data.texture.resource_path:
		texture_path = data.texture.resource_path
	else:
		texture_path = str(data.texture)
	
	print("Pickup: Setting up sprite with texture path: ", texture_path)
	
	# Auto-set frame counts based on pickup type (can be overridden in Inspector)
	if hframes == 1 and vframes == 1:  # Only auto-set if using defaults
		if "Coin" in texture_path or data is CoinData:
			hframes = 6
			vframes = 1
			print("Pickup: Auto-set Coin to 6 hframes, 1 vframe")
		elif "1_Up" in texture_path or data is DrugPowerupData:
			hframes = 16
			vframes = 1
			print("Pickup: Auto-set 1_Up to 16 hframes, 1 vframe")
	
	# Use configured frame counts (set in Inspector or auto-detected above)
	var total_frames = hframes * vframes
	
	# Set sprite frames
	sprite.hframes = hframes
	sprite.vframes = vframes
	sprite.frame = 0
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	
	print("Pickup: Configured spritesheet - hframes: ", hframes, ", vframes: ", vframes, ", total frames: ", total_frames)
	
	# Animate if multiple frames
	if total_frames > 1:
		animation_tween = create_tween()
		animation_tween.set_loops()
		var anim_duration = total_frames * 0.1  # ~10 FPS
		animation_tween.tween_method(_set_frame, 0, total_frames - 1, anim_duration)
		print("Pickup: Started animation with ", total_frames, " frames")
	
	# Connect body_entered signal
	body_entered.connect(_on_body_entered)

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
			if data is CoinData:
				var coin_sound = load("res://Assets (Little Runmo)/8_Music_Sound Effects/Coin.wav")
				if coin_sound:
					sound_to_play = AudioStreamPlayer2D.new()
					sound_to_play.stream = coin_sound
					get_tree().root.add_child(sound_to_play)
					sound_to_play.global_position = global_position
					sound_to_play.play()
					# Auto-delete sound player when finished
					sound_to_play.finished.connect(func(): sound_to_play.queue_free())
			elif data is DrugPowerupData:
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
		if data:
			data.apply_effect(body)
		
		# Spawn particles if available
		if data and data.particle_effect:
			var particles = data.particle_effect.instantiate()
			get_parent().add_child(particles)
			particles.global_position = global_position
		
		# Delete immediately - sound will continue playing independently
		queue_free()
