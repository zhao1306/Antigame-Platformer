class_name PickupData
extends Resource

# Base class for all pickup items
# Subclasses will override apply_effect() to define what happens when collected

@export var particle_effect: PackedScene = null
@export var texture: Texture2D = null

# Override this in subclasses to define pickup behavior
func apply_effect(_player_node: Node) -> void:
	pass
