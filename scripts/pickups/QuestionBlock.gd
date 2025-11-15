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

func _ready():
	# Setup sprite for 5 frames (1 base + 4 animation)
	sprite.hframes = 5
	sprite.vframes = 1
	sprite.frame = 0
	sprite.centered = true
	
	# Connect hit detector
	if hit_detector:
		hit_detector.body_entered.connect(_on_hit_detector_body_entered)

func _on_hit_detector_body_entered(body: Node2D):
	# Only trigger if hit from below and not already hit
	if is_hit:
		return
	
	# Check if it's the player
	if body.is_in_group("player"):
		var player = body as CharacterBody2D
		if player:
			# Check if player is moving upward (hitting from below)
			# Also check if player's top is below the block's bottom
			var player_top = player.global_position.y - 8  # Approximate player top
			var block_bottom = global_position.y + 8
			
			if player.velocity.y < 0 and player_top < block_bottom:
				hit_from_below()

func hit_from_below():
	if is_hit:
		return
	
	is_hit = true
	print("QuestionBlock: Hit from below!")
	
	# Play animation: frames 0->1->2->3->4 (stay on frame 4)
	animation_tween = create_tween()
	animation_tween.set_parallel(false)
	
	# Animate through frames 1-4 (skip frame 0, it's the base)
	for frame in range(1, 5):
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
	pickup.data = powerup_data
	pickup.global_position = global_position + Vector2(0, -32)  # Spawn above block
	
	# Enable movement if requested
	if move_powerup:
		pickup.set_movement_enabled(true)
	
	get_parent().add_child(pickup)
	print("QuestionBlock: Spawned powerup at ", pickup.global_position)

