class_name DrugPowerupData
extends PickupData

# Power-up pickup data - triggers power-up transition

func apply_effect(player_node: Node) -> void:
	if player_node.has_method("start_powerup_transition"):
		print("Power-up collected! Starting transition...")
		player_node.start_powerup_transition()

