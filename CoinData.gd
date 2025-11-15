class_name CoinData
extends PickupData

# Coin pickup data - adds coins to player

func apply_effect(player_node: Node) -> void:
	if player_node.has_method("add_coin"):
		player_node.add_coin(1)
		print("Coin collected! Total coins: ", player_node.coin_count)

