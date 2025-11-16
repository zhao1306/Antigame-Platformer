extends StaticBody2D

# Question Block - spawns powerups when hit from below

@export var powerup_data: PickupData  # The pickup to spawn (set in Inspector)
@export var move_powerup: bool = true  # Whether the spawned powerup should move right

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hit_detector: Area2D = $HitDetector

var is_hit: bool = false
var animation_tween: Tween
var total_frames: int = 5  # 1 base + 4 animation frames
var block_count: int = 0

func _ready():
	# Load default powerup_data if not set in Inspector (matching MainScene pattern)
	if not powerup_data:
		print("No powerup_data set, loading default")
		powerup_data = load("res://resources/pickups/drug_powerup_data.tres")
	
	# Ensure sprite is visible and properly configured
	sprite.visible = true
	sprite.scale = Vector2(1, 1)  # Ensure scale is set
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	
	# Setup sprite for 5 frames (1 base + 4 animation)
	sprite.hframes = 5
	sprite.vframes = 1
	sprite.frame = 0
	
	# Connect hit detector
	if hit_detector:
		hit_detector.body_entered.connect(_on_hit_detector_body_entered)

func _on_hit_detector_body_entered(body: Node2D):
	# Only trigger if hit from below and not already hit
	if is_hit:
		print("already hit")
		return
	
	# Find the player - check the body itself or its parent
	var player: CharacterBody2D = null
	if body is CharacterBody2D and body.is_in_group("player"):
		player = body
	else:
		# Check if parent is the player
		var parent = body.get_parent()
		if parent is CharacterBody2D and parent.is_in_group("player"):
			player = parent
	
	if player:
		# Check if player is moving upward (hitting from below)
		if (abs(player.global_position.x - global_position.x) < 16):
			hit_from_below()

func hit_from_below():
	print("hit dected from below")
	if is_hit:
		return
	
	is_hit = true
	print("QuestionBlock: Hit from below!")
	
	# Play animation: frames 0->1->2->3->4 (stay on frame 4)
	animation_tween = create_tween()
	animation_tween.set_parallel(false)
	
	# Animate through frames 1-4 (skip frame 0, it's the base)
	for frame in range(1, 4):
		animation_tween.tween_callback(func(): sprite.frame = frame)
		animation_tween.tween_interval(0.1)  # 100ms per frame
	
	# Stay on frame 4 (inert block)
	animation_tween.tween_callback(func(): sprite.frame = 4)
	
	# Spawn powerup
	if powerup_data:
		spawn_powerup()

func spawn_powerup():
	var pickup_scene = load("res://scenes/pickups/Pickup.tscn")
	
	if not pickup_scene:
		print("QuestionBlock: ERROR - Could not load Pickup scene!")
		return
	
	var pickup = pickup_scene.instantiate()
	pickup.name = "PowerUp_block_" + str(block_count)
	pickup.data = powerup_data
	# Set position relative to scene root (MainScene pattern uses position, but we need global)
	pickup.global_position = global_position + Vector2(0, -16)  # Spawn above block
	
	# Enable movement if requested
	if move_powerup:
		pickup.set_movement_enabled(true)
	
	# Add to scene root (like MainScene does), not as child of QuestionBlock
	# Use call_deferred to avoid "can't change this state while flushing queries" error
	# This happens because we're adding a node during a physics signal callback
	get_tree().current_scene.call_deferred("add_child", pickup)
	print("QuestionBlock: Spawned powerup at ", pickup.global_position)
