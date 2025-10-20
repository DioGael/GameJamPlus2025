extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_respawn"):
		body.set_respawn(global_position)
	pass # Replace with function body.
