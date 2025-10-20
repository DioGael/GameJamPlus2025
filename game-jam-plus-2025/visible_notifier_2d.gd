# Add this to each character scene as a child node
extends VisibleOnScreenNotifier2D

@onready var character = get_parent()

func _ready():
	# Connect the signal
	screen_exited.connect(_on_screen_exited)

func _on_screen_exited():
	if character and character.has_method("die"):
		character.die()
