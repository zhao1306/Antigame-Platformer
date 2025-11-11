@tool
extends EditorScript

# This script automatically adds rectangular collision to all tiles in your TileSet
# To run: Editor > Run Script (or press Ctrl+Shift+X), then select this file

func _run():
	print("Adding collision to all tiles...")
	
	# Open the scene
	var scene_path = "res://node_2d.tscn"
	var scene = load(scene_path) as PackedScene
	
	if not scene:
		print("ERROR: Could not load scene: ", scene_path)
		return
	
	# Instantiate the scene to access nodes
	var scene_instance = scene.instantiate()
	var tilemap_layer = scene_instance.get_node_or_null("TileMapLayer")
	
	if not tilemap_layer:
		print("ERROR: Could not find TileMapLayer node")
		scene_instance.queue_free()
		return
	
	var tileset = tilemap_layer.tile_set
	if not tileset:
		print("ERROR: TileMapLayer has no TileSet")
		scene_instance.queue_free()
		return
	
	print("Found TileSet with ", tileset.get_source_count(), " sources")
	
	var tiles_processed = 0
	
	# Iterate through all sources in the TileSet
	for source_id in range(tileset.get_source_count()):
		var source = tileset.get_source(source_id)
		
		if source is TileSetAtlasSource:
			var atlas_source = source as TileSetAtlasSource
			var texture = atlas_source.texture
			
			if not texture:
				continue
			
			# Get the texture size and tile size
			var texture_size = texture.get_size()
			var tile_size = atlas_source.texture_region_size
			
			if tile_size.x == 0 or tile_size.y == 0:
				tile_size = Vector2i(16, 16)  # Default to 16x16 if not set
			
			var tiles_x = int(texture_size.x / tile_size.x)
			var tiles_y = int(texture_size.y / tile_size.y)
			
			print("Processing atlas source ", source_id, ": ", tiles_x, "x", tiles_y, " tiles (", tile_size, " each)")
			
			# Iterate through all tiles in this atlas
			for x in range(tiles_x):
				for y in range(tiles_y):
					var atlas_coords = Vector2i(x, y)
					
					# Check if this tile exists in the atlas
					if atlas_source.has_tile(atlas_coords):
						# Create a rectangle polygon covering the full tile
						# Physics layer 0
						var physics_layer = 0
						
						# Rectangle covering the full tile (centered at 0,0)
						var half_size = Vector2(tile_size.x / 2.0, tile_size.y / 2.0)
						var polygon = PackedVector2Array([
							Vector2(-half_size.x, -half_size.y),  # Top-left
							Vector2(half_size.x, -half_size.y),   # Top-right
							Vector2(half_size.x, half_size.y),    # Bottom-right
							Vector2(-half_size.x, half_size.y)    # Bottom-left
						])
						
						# Set the physics polygon for this tile
						atlas_source.set_tile_physics_polygon_points(physics_layer, atlas_coords, 0, polygon)
						
						tiles_processed += 1
	
	print("Done! Added collision to ", tiles_processed, " tiles")
	
	# Save the scene with the updated TileSet
	var packed_scene = PackedScene.new()
	packed_scene.pack(scene_instance)
	var error = ResourceSaver.save(packed_scene, scene_path)
	
	if error == OK:
		print("Scene saved successfully!")
	else:
		print("ERROR saving scene: ", error)
	
	scene_instance.queue_free()

