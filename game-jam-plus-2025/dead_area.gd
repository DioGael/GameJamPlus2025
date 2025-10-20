extends Area2D

@onready var character = get_parent()

func _on_body_entered(body: Node2D) -> void:
	if character != null:
		character.die()
	pass # Replace with function body.
