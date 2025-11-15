extends Node2D

# 1. DECLARE and PRE-FIND your nodes here.
@onready var camera: Camera2D = get_tree().get_first_node_in_group("main_camera")
@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")

# --- Puzzle Room Data Structure ---
# Each puzzle room stores: trigger, target, and wall positions
var puzzle_rooms: Array[Dictionary] = []
var registered_triggers: Array[Area2D] = []

# A giant number to act as "no limit"
var NO_LIMIT = 10000000

# Track which puzzle room the player is currently in (null if none)
var current_puzzle_room: Area2D = null

# This runs once at the start of the game
func _ready():
	if not camera or not player:
		print("ERROR: A required node was not found!")
	
	# Register all puzzle rooms here - just add them to the array!
	register_puzzle_room($PuzzleRoom_1_Trigger, $PuzzleRoom_1_CamTarget)
	# To add more puzzle rooms, just add more lines:
	# register_puzzle_room($PuzzleRoom_2_Trigger, $PuzzleRoom_2_CamTarget)
	
	# Calculate puzzle room walls
	calculate_all_puzzle_room_walls()
	
	# Wait one frame to ensure everything is initialized
	await get_tree().process_frame
	update_camera_limits()
	
	# Uncomment the line below to spawn test pickups automatically
	spawn_test_pickups()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Update camera limits dynamically based on player position
	update_camera_limits()

# --- Register a puzzle room (call this for each puzzle room) ---
func register_puzzle_room(trigger: Area2D, target: Marker2D):
	if not trigger or not target:
		print("ERROR: Invalid puzzle room trigger or target!")
		return
	
	# Skip if already registered
	if trigger in registered_triggers:
		return
	
	# Connect signals automatically
	trigger.body_entered.connect(_on_puzzle_room_trigger_body_entered.bind(trigger))
	trigger.body_exited.connect(_on_puzzle_room_trigger_body_exited)
	
	# Track this trigger
	registered_triggers.append(trigger)
	
	# Add to puzzle rooms array
	puzzle_rooms.append({
		"trigger": trigger,
		"target": target,
		"left_wall": 0.0,   # Will be calculated
		"right_wall": 0.0   # Will be calculated
	})

# --- Calculate puzzle room walls from trigger area ---
func calculate_puzzle_room_walls(trigger: Area2D) -> Dictionary:
	if not trigger:
		return {"left_wall": 0.0, "right_wall": 0.0}
	
	# Find the collision shape in the trigger area
	var collision_shape: CollisionShape2D = trigger.get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		print("WARNING: Puzzle room trigger has no CollisionShape2D!")
		return {"left_wall": 0.0, "right_wall": 0.0}
	
	# Get the shape and calculate its bounds
	var shape = collision_shape.shape
	var shape_rect: Rect2
	
	if shape is RectangleShape2D:
		var rect_shape = shape as RectangleShape2D
		var size = rect_shape.size
		var center = collision_shape.position
		shape_rect = Rect2(center - size / 2, size)
	elif shape is CircleShape2D:
		var circle_shape = shape as CircleShape2D
		var radius = circle_shape.radius
		var center = collision_shape.position
		shape_rect = Rect2(center - Vector2(radius, radius), Vector2(radius * 2, radius * 2))
	else:
		shape_rect = shape.get_rect()
	
	# Convert to global coordinates
	var global_rect = Rect2(
		trigger.global_position + shape_rect.position,
		shape_rect.size
	)
	
	return {
		"left_wall": global_rect.position.x,
		"right_wall": global_rect.position.x + global_rect.size.x
	}

# --- Calculate walls for all puzzle rooms ---
func calculate_all_puzzle_room_walls():
	for room in puzzle_rooms:
		var walls = calculate_puzzle_room_walls(room["trigger"])
		room["left_wall"] = walls["left_wall"]
		room["right_wall"] = walls["right_wall"]

# --- Update camera limits based on player position ---
func update_camera_limits():
	if not camera or not player:
		return
	
	var player_x = player.global_position.x
	
	# Find which puzzle room player is in (if any)
	var current_room: Dictionary = {}
	for room in puzzle_rooms:
		var bounds = calculate_puzzle_room_walls(room["trigger"])
		if player_x >= bounds["left_wall"] and player_x <= bounds["right_wall"]:
			current_room = room
			break
	
	if current_room != {}:
		# Player is inside a puzzle room
		# Set limits to puzzle room walls
		camera.limit_left = current_room["left_wall"]
		camera.limit_right = current_room["right_wall"]
		camera.limit_top = -NO_LIMIT
		camera.limit_bottom = NO_LIMIT
	else:
		# Player is outside puzzle rooms
		# Prevent camera from scrolling into puzzle rooms
		var leftmost_room_left = INF
		var rightmost_room_right = -INF
		
		for room in puzzle_rooms:
			if room["left_wall"] < leftmost_room_left:
				leftmost_room_left = room["left_wall"]
			if room["right_wall"] > rightmost_room_right:
				rightmost_room_right = room["right_wall"]
		
		# If player is to the left of all puzzle rooms, restrict right scrolling
		# If player is to the right of all puzzle rooms, allow free scrolling right
		if player_x < leftmost_room_left:
			camera.limit_left = -NO_LIMIT
			camera.limit_right = leftmost_room_left
		elif player_x > rightmost_room_right:
			camera.limit_left = -NO_LIMIT
			camera.limit_right = NO_LIMIT
		else:
			# Player is between puzzle rooms - allow free scrolling
			camera.limit_left = -NO_LIMIT
			camera.limit_right = NO_LIMIT
		
		camera.limit_top = -NO_LIMIT
		camera.limit_bottom = NO_LIMIT

# --- Universal signal handlers (work for all puzzle rooms) ---
func _on_puzzle_room_trigger_body_entered(body: Node2D, trigger: Area2D):
	if body.is_in_group("player"):
		current_puzzle_room = trigger
		# Camera limits will update automatically in _process

func _on_puzzle_room_trigger_body_exited(body: Node2D):
	if body.is_in_group("player"):
		current_puzzle_room = null
		# Camera limits will update automatically in _process

# --- Helper function to spawn test pickups ---
func spawn_test_pickups():
	var pickup_scene = load("res://Pickup.tscn")
	var coin_data = load("res://coin_data.tres")
	var powerup_data = load("res://drug_powerup_data.tres")
	
	if not pickup_scene or not coin_data or not powerup_data:
		print("ERROR: Could not load pickup scene or data!")
		return
	
	# Spawn a few coins near the player's starting position
	var coin_positions = [
		Vector2(100, 0),   # Right of spawn
		Vector2(200, 0),   # Further right
		Vector2(300, -50), # Up and right
	]
	
	for i in range(coin_positions.size()):
		var coin = pickup_scene.instantiate()
		coin.name = "Coin_" + str(i + 1)
		coin.data = coin_data
		coin.position = coin_positions[i]
		add_child(coin)
		print("Spawned coin at: ", coin_positions[i])
	
	# Spawn a power-up
	var powerup = pickup_scene.instantiate()
	powerup.name = "PowerUp_1"
	powerup.data = powerup_data
	powerup.position = Vector2(400, -50)  # Further right and up
	add_child(powerup)
	print("Spawned power-up at: ", powerup.position)
