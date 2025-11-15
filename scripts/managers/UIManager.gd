extends Node

# UI Manager - Autoload singleton (parallel to TimeStateManager)
# Handles UI elements (coin counter) and visual effects (saturation, flash via shader)

var ui_scene: CanvasLayer  # Reference to UI.tscn instance in main scene
var screen_effect: ColorRect  # Full-screen shader overlay
var shader_material: ShaderMaterial
var flash_sound: AudioStreamPlayer
var coin_counter: Label
var time_manager: Node

@export var flash_brightness: float = 0.5  # Brightness value for flash effect
@export var flash_duration: float = 0.1
@export var time_between_flashes: float = 0.5

func _ready():
	time_manager = get_node("/root/TimeStateManager")
	
	# Wait for main scene to be ready
	await get_tree().process_frame
	
	print("UIManager: Starting initialization...")
	print("UIManager: Current scene: ", get_tree().current_scene)
	print("UIManager: Root children count: ", get_tree().root.get_child_count())
	
	# Find UI scene instance in main scene
	var main_scene = get_tree().current_scene
	print("UIManager: Main scene: ", main_scene, " (name: ", main_scene.name if main_scene else "null", ")")
	
	if main_scene:
		ui_scene = main_scene.get_node_or_null("UI")
		if ui_scene:
			screen_effect = ui_scene.get_node_or_null("ScreenEffect")
			flash_sound = ui_scene.get_node_or_null("FlashSound")
			coin_counter = ui_scene.get_node_or_null("CoinCounter")
			
			# Get shader material from ScreenEffect
			if screen_effect and screen_effect.material:
				shader_material = screen_effect.material as ShaderMaterial
				if shader_material:
					print("UIManager: Shader material found and initialized")
				else:
					print("UIManager: ERROR - ScreenEffect material is not a ShaderMaterial!")
			else:
				print("UIManager: ERROR - ScreenEffect or material not found!")
			
			print("UIManager: UI scene found - ScreenEffect: ", screen_effect, ", FlashSound: ", flash_sound, ", CoinCounter: ", coin_counter)
		else:
			print("UIManager: ERROR - UI scene not found in main scene!")
	else:
		print("UIManager: ERROR - Main scene not found!")
	
	# Connect to time state changes for saturation effects
	if time_manager:
		time_manager.time_state_changed.connect(_on_time_state_changed)
		# Set initial saturation
		await get_tree().process_frame
		update_saturation_for_state(time_manager.current_state)
	
	# Initialize UI elements
	if coin_counter:
		coin_counter.text = "Coins: 0"
	
	# Initialize shader to normal values
	if shader_material:
		shader_material.set_shader_parameter("brightness", 0.0)
		shader_material.set_shader_parameter("contrast", 1.0)
		shader_material.set_shader_parameter("saturation", 1.0)

# Call this function to start the 3-beat countdown
func play_timing_cues():
	if not shader_material:
		print("UIManager: ERROR - Shader material is null!")
		return
	if not flash_sound:
		print("UIManager: ERROR - FlashSound is null!")
		return
	
	print("UIManager: Starting timing cues - flash_brightness=", flash_brightness)
	
	var tween = create_tween()
	tween.set_parallel(false)  # Sequential, not parallel
	
	# Flash 1 - use brightness for flash effect
	tween.tween_callback(flash_sound.play)
	tween.tween_method(set_brightness, 0.0, flash_brightness, flash_duration / 2.0)
	tween.tween_method(set_brightness, flash_brightness, 0.0, flash_duration / 2.0)
	tween.tween_interval(time_between_flashes)
	
	# Flash 2
	tween.tween_callback(flash_sound.play)
	tween.tween_method(set_brightness, 0.0, flash_brightness, flash_duration / 2.0)
	tween.tween_method(set_brightness, flash_brightness, 0.0, flash_duration / 2.0)
	tween.tween_interval(time_between_flashes)
	
	# Flash 3
	tween.tween_callback(flash_sound.play)
	tween.tween_method(set_brightness, 0.0, flash_brightness, flash_duration / 2.0)
	tween.tween_method(set_brightness, flash_brightness, 0.0, flash_duration / 2.0)

# Flickers saturation during power-up transition
signal flicker_complete

func play_powerup_flicker():
	var tween = create_tween()
	
	# Flicker pattern: 1.0 → 0.0 → 1.5 → 0.0 → 1.5
	tween.tween_method(set_saturation, 1.0, 0.0, 0.2)
	tween.tween_method(set_saturation, 0.0, 1.5, 0.2)
	tween.tween_method(set_saturation, 1.5, 0.0, 0.2)
	tween.tween_method(set_saturation, 0.0, 1.5, 0.2)
	tween.tween_interval(0.3)  # Hold final saturation briefly
	
	tween.finished.connect(flicker_complete.emit)
	await flicker_complete

# Update coin counter display
func update_coin_counter(count: int):
	if coin_counter:
		coin_counter.text = "Coins: " + str(count)

# Set saturation using shader (0.0 = greyscale, 1.0 = normal, >1.0 = high saturation)
func set_saturation(value: float):
	if not shader_material:
		print("UIManager: ERROR - Cannot set saturation, shader material not found!")
		return
	shader_material.set_shader_parameter("saturation", value)

# Set brightness using shader (for flash effects)
func set_brightness(value: float):
	if not shader_material:
		print("UIManager: ERROR - Cannot set brightness, shader material not found!")
		return
	shader_material.set_shader_parameter("brightness", value)

# Set contrast using shader
func set_contrast(value: float):
	if not shader_material:
		print("UIManager: ERROR - Cannot set contrast, shader material not found!")
		return
	shader_material.set_shader_parameter("contrast", value)

# Handle time state changes for saturation effects
func update_saturation_for_state(state: int):
	match state:
		TimeStateManager.TimeState.SLOW:
			set_saturation(0.0)  # Greyscale
		TimeStateManager.TimeState.FAST:
			set_saturation(1.0)  # Normal
		TimeStateManager.TimeState.POWERUP:
			set_saturation(1.5)  # High saturation

func _on_time_state_changed(new_state: int):
	update_saturation_for_state(new_state)
