extends Camera2D

@export var character1: Node2D
@export var character2: Node2D
@export var smoothing_speed: float = 15.0
@export var min_zoom: float = 1.2
@export var max_zoom: float = 2
@export var zoom_sensitivity: float = 500.0  # Higher = less zoom change

func _process(delta):
	if character1 and character2:
		var midpoint = (character1.global_position + character2.global_position) / 2
		
		# Smooth movement
		global_position = global_position.lerp(midpoint, smoothing_speed * delta)
		
		# CORRECTED: Zoom out when characters are far apart, zoom in when close
		var distance = character1.global_position.distance_to(character2.global_position)
		var target_zoom = clamp(Vector2.ONE * (zoom_sensitivity / distance), 
							   Vector2(min_zoom, min_zoom), 
							   Vector2(max_zoom, max_zoom))
		zoom = zoom.lerp(target_zoom, smoothing_speed * delta)
