extends Node

# UI Manager - Autoload singleton (parallel to TimeStateManager)
# Handles UI elements (coin counter) and visual effects (saturation, flash via shader)

var ui_scene: CanvasLayer  # Reference to UI.tscn instance in main scene
var screen_effect: ColorRect  # Full-screen shader overlay
var shader_material: ShaderMaterial
var flash_sound: AudioStreamPlayer
var switch_sound: AudioStreamPlayer
var coin_counter: Label
var time_manager: Node

@export var flash_brightness: float = 0.1  # Brightness value for flash effect
@export var flash_duration: float = 0.1
@export var time_between_flashes: float = 0.5

# Rhythm timer system
var timer_enabled: bool = false
var beat_duration: float = 0.5  # 120 BPM = 60/120 seconds per beat
var rhythm_timer: Timer
var beat_count: int = 0  # Current beat count (mod 8)

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
			switch_sound = ui_scene.get_node_or_null("SwitchSound")
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
	
	# Setup rhythm timer
	rhythm_timer = Timer.new()
	rhythm_timer.wait_time = beat_duration
	rhythm_timer.one_shot = false
	rhythm_timer.timeout.connect(_on_rhythm_beat)
	add_child(rhythm_timer)

func _input(event):
	# Press L to toggle rhythm timer
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		toggle_rhythm_timer()

func toggle_rhythm_timer():
	timer_enabled = !timer_enabled
	
	if timer_enabled:
		print("UIManager: Rhythm timer ENABLED")
		# Disable auto-switching in TimeStateManager
		if time_manager and time_manager.has_method("set_auto_switch"):
			time_manager.set_auto_switch(false)
		# Reset and start at 1
		beat_count = 1
		rhythm_timer.start()
		_on_rhythm_beat()  # Start immediately
	else:
		print("UIManager: Rhythm timer DISABLED")
		rhythm_timer.stop()
		# Re-enable auto-switching
		if time_manager and time_manager.has_method("set_auto_switch"):
			time_manager.set_auto_switch(true)

func _on_rhythm_beat():
	if not timer_enabled:
		return
	
	var beat_mod = beat_count % 8
	
	# Beats 6, 7, 0 (mod 8) = flash
	if beat_count > 0 and (beat_mod == 6 or beat_mod == 7 or beat_mod == 0):
		_play_single_flash()
	
	# On beat 1 (mod 8 == 1) but excluding the first 1, switch modes
	if beat_mod == 1 and beat_count > 8:
		_switch_time_state()
		
	# print("UIManager: Beat ", beat_count)
	
	beat_count += 1

func _play_single_flash():
	# Play a single flash with sound
	if flash_sound:
		flash_sound.play()
	
	# Quick brightness flash
	if shader_material:
		var tween = create_tween()
		tween.tween_method(set_brightness, 0.0, flash_brightness, flash_duration / 2.0)
		tween.tween_method(set_brightness, flash_brightness, 0.0, flash_duration / 2.0)

func _switch_time_state():
	if not time_manager:
		return
	
	if switch_sound:
		switch_sound.play()
	
	# Switch between SLOW and FAST
	var new_state: int
	if time_manager.current_state == TimeStateManager.TimeState.SLOW:
		new_state = TimeStateManager.TimeState.FAST
	else:
		new_state = TimeStateManager.TimeState.SLOW
	
	time_manager.set_state(new_state)
	print("UIManager: Time state switched to: ", TimeStateManager.TimeState.keys()[new_state])

# Flickers saturation during power-up transition
signal flicker_complete

func play_powerup_flicker():
	var tween = create_tween()
	
	# Flicker pattern: 1.0 → 0.0 → 1.5 → 0.0 → 1.5
	tween.tween_method(set_saturation, 1.0, 0.0, 0.05)
	tween.tween_method(set_saturation, 0.0, 1.5, 0.05)
	tween.tween_method(set_saturation, 1.5, 0.0, 0.05)
	tween.tween_method(set_saturation, 0.0, 1.5, 0.05)
	tween.finished.connect(flicker_complete.emit)
	await flicker_complete
	set_saturation(3.0)  # Hyper-real super colorful saturated look

func play_powerup_exit_flicker():
	var tween = create_tween()
	
	# Exit flicker pattern: 3.0 → 1.5 → 0.0 → 1.5 → 1.0 (reverse transition)
	tween.tween_method(set_saturation, 3.0, 1.5, 0.05)
	tween.tween_method(set_saturation, 1.5, 0.0, 0.05)
	tween.tween_method(set_saturation, 0.0, 1.5, 0.05)
	tween.tween_method(set_saturation, 1.5, 1.0, 0.05)
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
			set_saturation(3.0)  # Hyper-real super colorful saturated look

func _on_time_state_changed(new_state: int):
	update_saturation_for_state(new_state)
