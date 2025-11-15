extends Node

# Visual Effects Manager - Controls color saturation and filters based on time state
# This should be an autoload (singleton) for global access

@onready var world_env: WorldEnvironment = get_tree().get_first_node_in_group("world_environment")

var time_manager: Node
var ui_manager: Node
var use_color_overlay: bool = true  # Use ColorRect overlay instead of Environment adjustments

func _ready():
	time_manager = get_node("/root/TimeStateManager")
	
	# Wait a frame for UI to be ready
	await get_tree().process_frame
	
	# Find UI manager for color overlay
	_find_ui_manager()
	
	# Connect to time state changes
	if time_manager:
		time_manager.time_state_changed.connect(_on_time_state_changed)
		# Set initial saturation based on current state (after UI is ready)
		await get_tree().process_frame
		update_saturation_for_state(time_manager.current_state)
	else:
		print("VisualEffectsManager: TimeStateManager not found!")
	
	# Find WorldEnvironment if not found via group
	if not world_env:
		world_env = get_tree().get_first_node_in_group("world_environment")
		if not world_env:
			# Try to find it in the main scene
			var main_scene = get_tree().root.get_child(0)
			world_env = main_scene.get_node_or_null("WorldEnvironment")
			if world_env:
				world_env.add_to_group("world_environment")
	
	# Prefer color overlay method (more reliable)
	if ui_manager and ui_manager.has_method("set_color_filter_saturation"):
		use_color_overlay = true
		print("VisualEffectsManager: Using CanvasModulate overlay for visual effects")
	elif world_env:
		use_color_overlay = false
		print("VisualEffectsManager: Using Environment adjustments for visual effects")
	else:
		print("VisualEffectsManager: Warning - No visual effects method available!")

func _find_ui_manager():
	# Try multiple methods to find UI manager
	ui_manager = get_tree().get_first_node_in_group("ui_manager")
	if not ui_manager:
		# Try to find it in the main scene
		var main_scene = get_tree().root.get_child(0)
		if main_scene:
			ui_manager = main_scene.get_node_or_null("UI")
			if ui_manager:
				ui_manager.add_to_group("ui_manager")
				print("VisualEffectsManager: Found UI manager at: ", ui_manager.get_path())
	
	if not ui_manager:
		print("VisualEffectsManager: ERROR - UI manager not found! Visual effects will not work.")
	else:
		print("VisualEffectsManager: UI manager found: ", ui_manager.name)

func set_saturation(value: float):
	# Try to find UI manager if not found yet
	if not ui_manager:
		_find_ui_manager()
	
	if use_color_overlay and ui_manager:
		# Use CanvasModulate overlay method
		if ui_manager.has_method("set_color_filter_saturation"):
			ui_manager.set_color_filter_saturation(value)
		else:
			print("VisualEffectsManager: UI manager missing set_color_filter_saturation method")
	else:
		# Try Environment adjustments method
		if not world_env or not world_env.environment:
			# Fallback: try to use UI manager anyway
			if ui_manager and ui_manager.has_method("set_color_filter_saturation"):
				use_color_overlay = true
				ui_manager.set_color_filter_saturation(value)
			return
		
		var env = world_env.environment
		
		# Try to access adjustments properties
		if env.get("adjustments_enabled") != null:
			# Property exists, use it
			if not env.adjustments_enabled:
				env.adjustments_enabled = true
			env.adjustments_saturation = value
		else:
			# Fallback to color overlay if Environment doesn't work
			if ui_manager and ui_manager.has_method("set_color_filter_saturation"):
				use_color_overlay = true
				ui_manager.set_color_filter_saturation(value)

func set_pink_filter(intensity: float):
	# Set pink filter overlay (0.0 = no filter, 1.0 = full pink)
	# Try to find UI manager if not found yet
	if not ui_manager:
		_find_ui_manager()
	
	if ui_manager and ui_manager.has_method("set_color_filter_pink"):
		ui_manager.set_color_filter_pink(intensity)
	else:
		var has_method_str = "N/A"
		if ui_manager:
			has_method_str = str(ui_manager.has_method("set_color_filter_pink"))
		print("VisualEffectsManager: UI manager not available for pink filter. ui_manager: ", ui_manager, " has_method: ", has_method_str)

func update_saturation_for_state(state: int):
	match state:
		TimeStateManager.TimeState.SLOW:
			set_saturation(0.0)  # Greyscale
			set_pink_filter(0.0)  # No pink filter
		TimeStateManager.TimeState.FAST:
			set_saturation(1.0)  # Normal
			set_pink_filter(0.0)  # No pink filter
		TimeStateManager.TimeState.POWERUP:
			set_saturation(1.5)  # High saturation
			set_pink_filter(0.3)  # Pink filter for power-up mode

func _on_time_state_changed(new_state: int):
	update_saturation_for_state(new_state)
