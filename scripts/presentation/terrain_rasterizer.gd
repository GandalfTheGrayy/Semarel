class_name TerrainRasterizer
extends RefCounted


static func rasterize(
	terrain_snapshot: PackedByteArray,
	storage_width: int,
	image_size: Vector2i,
) -> Image:
	assert(storage_width > 0, "Terrain storage width must be positive")
	assert(image_size.x > 0 and image_size.y > 0, "Rasterized image dimensions must be positive")
	assert(image_size.x <= storage_width, "Image width cannot exceed terrain storage width")
	assert(
		terrain_snapshot.size() >= storage_width * image_size.y,
		"Terrain snapshot is too small for the requested image",
	)

	var image := Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	for y in range(image_size.y):
		for x in range(image_size.x):
			var terrain := terrain_snapshot[y * storage_width + x]
			image.set_pixel(x, y, TerrainPalette.get_color(terrain))
	return image
