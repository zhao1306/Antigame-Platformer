extends CanvasLayer

# UI Manager - Handles visual effects and UI elements

@onready var flash_rect: ColorRect = $FlashRect
@onready var flash_sound: AudioStreamPlayer = $FlashSound
@onready var coin_counter: Label = $CoinCounter

var color_filter: CanvasModulate

@export var flash_opacity: float = 0.2
@export var flash_duration: float = 0.1
@export var time_between_flashes: float = 0.5

var visual_effects_manager: Node
var current_saturation: float = 1.0
var current_pink_intensity: float = 0.0

func _ready():
	visual_effects_manager = get_node("/root/VisualEffectsManager")
	add_to_group("ui_manager")
	
	# Find ColorFilter in the VisualEffectsLayer (on layer 0, affects entire game)
	var main_scene = get_tree().root.get_child(0)
	if main_scene:
		var visual_effects_layer = main_scene.get_node_or_null("VisualEffectsLayer")
		if visual_effects_layer:
			color_filter = visual_effects_layer.get_node_or_null("ColorFilter")
			if color_filter:
				color_filter.color = Color(1, 1, 1, 1)
				print("UIManager: ColorFilter found and initialized")
			else:
				print("UIManager: ERROR - ColorFilter node not found in VisualEffectsLayer")
		else:
			print("UIManager: ERROR - VisualEffectsLayer not found")
	
	# Initialize flash rect to invisible
	if flash_rect:
		flash_rect.modulate.a = 0.0
		print("UIManager: FlashRect initialized")
	else:
		print("UIManager: WARNING - FlashRect not found!")
	
	# Check flash sound
	if flash_sound:
		if flash_sound.stream:
			print("UIManager: FlashSound has stream: ", flash_sound.stream.resource_path)
		else:
			print("UIManager: WARNING - FlashSound has no stream assigned!")
	else:
		print("UIManager: WARNING - FlashSound not found!")
	
	# Initialize coin counter
	if coin_counter:
		coin_counter.text = "Coins: 0"
		print("UIManager: CoinCounter initialized")
	else:
		print("UIManager: WARNING - CoinCounter not found!")

# Call this function to start the 3-beat countdown
func play_timing_cues():
	if not flash_rect or not flash_sound:
		return
	
	var tween = create_tween()
	
	# Flash 1
	tween.tween_callback(flash_sound.play)
	tween.tween_property(flash_rect, "modulate:a", flash_opacity, flash_duration / 2.0)
	tween.tween_property(flash_rect, "modulate:a", 0.0, flash_duration / 2.0)
	tween.tween_interval(time_between_flashes)
	
	# Flash 2
	tween.tween_callback(flash_sound.play)
	tween.tween_property(flash_rect, "modulate:a", flash_opacity, flash_duration / 2.0)
	tween.tween_property(flash_rect, "modulate:a", 0.0, flash_duration / 2.0)
	tween.tween_interval(time_between_flashes)
	
	# Flash 3
	tween.tween_callback(flash_sound.play)
	tween.tween_property(flash_rect, "modulate:a", flash_opacity, flash_duration / 2.0)
	tween.tween_property(flash_rect, "modulate:a", 0.0, flash_duration / 2.0)

# Flickers saturation during power-up transition
# Returns a signal that can be awaited
signal flicker_complete

func play_powerup_flicker():
	if not visual_effects_manager:
		flicker_complete.emit()
		return
	
	var tween = create_tween()
	
	# Flicker pattern: 1.0 → 0.0 → 1.5 → 0.0 → 1.5
	tween.tween_method(visual_effects_manager.set_saturation, 1.0, 0.0, 0.2)
	tween.tween_method(visual_effects_manager.set_saturation, 0.0, 1.5, 0.2)
	tween.tween_method(visual_effects_manager.set_saturation, 1.5, 0.0, 0.2)
	tween.tween_method(visual_effects_manager.set_saturation, 0.0, 1.5, 0.2)
	tween.tween_interval(0.3)  # Hold final saturation briefly
	
	# Connect tween finished to signal
	tween.finished.connect(flicker_complete.emit)
	
	await flicker_complete

# Update coin counter display
func update_coin_counter(count: int):
	if coin_counter:
		coin_counter.text = "Coins: " + str(count)

# Set color filter saturation (0.0 = greyscale, 1.0 = normal, >1.0 = high saturation)
func set_color_filter_saturation(value: float):
	current_saturation = value
	_update_color_filter()

# Set pink filter overlay (0.0 = no filter, 1.0 = full pink)
func set_color_filter_pink(intensity: float):
	current_pink_intensity = intensity
	_update_color_filter()

# Update the color filter combining saturation and pink effects
func _update_color_filter():
	if not color_filter:
		return
	
	# Start with saturation effect
	var final_color = Color(1, 1, 1, 1)
	
	if current_saturation <= 0.0:
		# Greyscale: desaturate by averaging RGB
		final_color = Color(0.5, 0.5, 0.5, 1)
	elif current_saturation < 1.0:
		# Partial saturation: interpolate between grey and normal
		var grey = 0.5
		final_color.r = lerp(grey, 1.0, current_saturation)
		final_color.g = lerp(grey, 1.0, current_saturation)
		final_color.b = lerp(grey, 1.0, current_saturation)
	elif current_saturation > 1.0:
		# High saturation: boost colors slightly
		var boost = (current_saturation - 1.0) * 0.2
		final_color.r = min(1.0, 1.0 + boost)
		final_color.g = min(1.0, 1.0 + boost)
		final_color.b = min(1.0, 1.0 + boost)
	
	# Add pink filter on top
	if current_pink_intensity > 0.0:
		# Blend pink tint with saturation
		var pink_tint = Color(1.0, 0.6, 0.9, 1.0)
		final_color.r = lerp(final_color.r, pink_tint.r, current_pink_intensity * 0.4)
		final_color.g = lerp(final_color.g, pink_tint.g, current_pink_intensity * 0.4)
		final_color.b = lerp(final_color.b, pink_tint.b, current_pink_intensity * 0.4)
	
	color_filter.color = final_color
