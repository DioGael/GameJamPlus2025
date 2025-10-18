extends CharacterBody2D

@export var player_id: int = 1  # Set this to 1 or 2 for each player instance
@export var speed: int = 200
@onready var carry_position = $CarryPosition
@onready var pickup_area = $PickupArea

var carried_player: Node2D = null
var carrier_player: Node2D = null  # Who is carrying this player
var can_pickup: bool = false
var nearby_players: Array[Node2D] = []

# Input action names
var move_left: String
var move_right: String
var move_up: String
var move_down: String
var interact: String

func _ready():
	# Set up input actions based on player_id
	move_left = "p%d_move_left" % player_id
	move_right = "p%d_move_right" % player_id
	move_up = "p%d_move_up" % player_id
	move_down = "p%d_move_down" % player_id
	interact = "p%d_interact" % player_id
	
	# Connect pickup area signals
	pickup_area.body_entered.connect(_on_pickup_area_body_entered)
	pickup_area.body_exited.connect(_on_pickup_area_body_exited)

func _physics_process(delta):
	# Only process movement if not being carried
	if carrier_player == null:
		# Movement input
		var direction = Vector2.ZERO
		direction.x = Input.get_axis(move_left, move_right)
		direction.y = Input.get_axis(move_up, move_down)
		velocity = direction.normalized() * speed
		move_and_slide()
	# Simple animation based on movement
	if carrier_player == null:
		if velocity.length() > 0:
			$Sprite2D.scale = Vector2(1.0, 0.9)  # Squish when moving
		else:
			$Sprite2D.scale = Vector2(1.0, 1.0)  # Normal when still
	# Update position if being carried
	if carrier_player != null:
		global_position = carrier_player.carry_position.global_position

func _input(event):
	# Only process input if not being carried
	if carrier_player == null and event.is_action_pressed(interact):
		if carried_player:
			throw_player(1.0)
		elif can_pickup and nearby_players.size() > 0:
			# Find the closest player that isn't being carried
			var target_player = null
			for player in nearby_players:
				if player.carrier_player == null and player != self:
					target_player = player
					break
			if target_player:
				pickup_player(target_player)

func pickup_player(target: Node2D):
	carried_player = target
	target.get_picked_up(self)  # Tell the other player they're being carried
	
	# Visual feedback
	modulate = Color(0.8, 1.0, 0.8)  # Light green tint
	target.modulate = Color(1.0, 0.8, 0.8)  # Light red tint
	
	can_pickup = false
	nearby_players.erase(target)

func get_picked_up(by: Node2D):
	carrier_player = by
	# Disable collision while being carried
	$CollisionShape2D.disabled = true

func drop_player():
	if not carried_player:
		return
	
	carried_player.get_dropped()
	
	# Reset visual feedback
	modulate = Color(1, 1, 1)
	carried_player.modulate = Color(1, 1, 1)
	
	carried_player = null
func throw_player(throw_strength: float):
	if carried_player:
		var throw_direction = Vector2(1, 0)  # Default right
		if velocity.length() > 0:
			throw_direction = velocity.normalized()
		
		drop_player()
		carried_player.velocity = throw_direction * throw_strength
func get_dropped():
	carrier_player = null
	# Re-enable collision
	$CollisionShape2D.disabled = false

func _on_pickup_area_body_entered(body):
	if body is CharacterBody2D and body.has_method("get_picked_up") and body != self:
		if not body in nearby_players:
			nearby_players.append(body)
			can_pickup = true
			
			# Visual feedback - highlight when pickup is available
			if carrier_player == null and carried_player == null:
				modulate = Color(0.9, 0.9, 1.2)  # Slight blue tint

func _on_pickup_area_body_exited(body):
	if body in nearby_players:
		nearby_players.erase(body)
		if nearby_players.size() == 0:
			can_pickup = false
		
		# Reset visual feedback
		if carrier_player == null and carried_player == null:
			modulate = Color(1, 1, 1)
