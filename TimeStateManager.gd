extends Node

# Time State Manager - Controls game time scale and state
# This should be an autoload (singleton) for global access

signal time_state_changed(new_state: int)

enum TimeState {
	SLOW,    # Slow motion state
	FAST,    # Fast motion state
	POWERUP  # Power-up mode (normal time, no scaling)
}

var current_state: TimeState = TimeState.FAST
var time_scale: float = 1.0  # Current time scale multiplier

# Time scale values for each state
const SLOW_SCALE: float = 0.75   # 3/4 speed
const FAST_SCALE: float = 1.25   # 5/4 speed
const POWERUP_SCALE: float = 1.0  # Normal speed

func _ready():
	update_time_scale()

func _input(event):
	# Debug controls: J = slow, K = fast
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_J:
			set_state(TimeState.SLOW)
		elif event.keycode == KEY_K:
			set_state(TimeState.FAST)

func set_state(new_state: TimeState):
	if current_state == new_state:
		return
	
	current_state = new_state
	update_time_scale()
	time_state_changed.emit(new_state)
	print("Time state changed to: ", TimeState.keys()[new_state])

func update_time_scale():
	match current_state:
		TimeState.SLOW:
			time_scale = SLOW_SCALE
		TimeState.FAST:
			time_scale = FAST_SCALE
		TimeState.POWERUP:
			time_scale = POWERUP_SCALE
	
	# Note: We don't use Engine.time_scale because we want to preserve player momentum
	# Instead, individual systems (gravity, enemies, etc.) will scale their physics manually

func get_time_scale() -> float:
	return time_scale

func is_slow() -> bool:
	return current_state == TimeState.SLOW

func is_fast() -> bool:
	return current_state == TimeState.FAST

func is_powerup() -> bool:
	return current_state == TimeState.POWERUP

