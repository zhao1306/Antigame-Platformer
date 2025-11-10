extends CharacterBody2D

# Set your player's speed and gravity
const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Get the gravity from the project settings (so all physics is consistent)
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get horizontal input (left/right arrows)
	var direction = Input.get_axis("ui_left", "ui_right")

	# Apply movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# This is the magic function that makes CharacterBody2D work
	move_and_slide()
