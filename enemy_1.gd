extends CharacterBody2D

@export var speed = 50.0
@export var health = 100
@export var damage = 10  # Урон, который враг наносит игроку
@export var patrol_points: Array[Node2D] = []
@export var wait_time = 2.0
@export var patrol_threshold = 5.0
@export var attack_range = 50.0
@export var stop_distance_from_player = 20.0  # Минимальное расстояние до игрока, на котором враг остановится
@export var chase_speed = 32
@export var player: Node2D = null
@export var attack_cooldown = 6.0
@export var attack_offset := Vector2(16, 0)

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_patrol_point = 0
var direction = Vector2.RIGHT
var state = "patrol"
var wait_timer = 0.0
var player_detected = false
var attack_timer = 0.0
var facing_right = true

@onready var animator = $AnimationPlayer
@onready var sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var damage_area = $DamageArea
@onready var attack_area = $AttackArea
@onready var attack_area_shape = $AttackArea/CollisionShape2D
@onready var health_bar = $HealthBar

func _ready():
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	damage_area.area_entered.connect(_on_damage_area_entered)
	attack_area_shape.disabled = true
	attack_area.add_to_group("enemy_attack")
	health_bar.max_value = health
	health_bar.value = health

func _physics_process(delta):
	match state:
		"patrol":
			_patrol(delta)
		"wait":
			_wait(delta)
		"chase":
			_chase_player(delta)
		"attack":
			_attack_player(delta)

	if not is_on_floor():
		velocity.y += gravity * delta
	
	move_and_slide()
	
	if player_detected and player:
		_update_state_by_distance()

	if attack_timer > 0:
		attack_timer -= delta

	_adjust_attack_area_position()

func _update_state_by_distance():
	if player:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= attack_range and attack_timer <= 0:
			velocity.x = 0
			state = "attack"
		else:
			state = "chase"

func _patrol(delta):
	if patrol_points.is_empty():
		return
	var target = patrol_points[current_patrol_point].global_position
	var distance = global_position.distance_to(target)
	if distance < patrol_threshold:
		current_patrol_point = (current_patrol_point + 1) % patrol_points.size()
		state = "wait"
		wait_timer = wait_time
		velocity.x = 0
		_update_animation("idle")
	else:
		direction = (target - global_position).normalized()
		velocity.x = direction.x * speed
		_update_animation("walk")
		_update_facing_direction(direction.x)
	attack_area_shape.disabled = true

func _wait(delta):
	velocity.x = 0
	wait_timer -= delta
	if wait_timer <= 0:
		state = "patrol"

func _chase_player(delta):
	if player:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		# Если враг ближе к игроку, чем на stop_distance_from_player, то он перестаёт двигаться
		if distance_to_player > stop_distance_from_player:
			direction = (player.global_position - global_position).normalized()
			velocity.x = direction.x * chase_speed
			_update_animation("run")
		else:
			velocity.x = 0  # Враг останавливается, если близко к игроку

		_update_facing_direction(direction.x)
		_update_state_by_distance()

func _attack_player(delta):
	if attack_timer <= 0:
		velocity.x = 0
		_update_animation("attack")
		attack_timer = attack_cooldown
	else:
		state = "chase"

func _update_animation(animation_name):
	if animator.has_animation(animation_name):
		animator.play(animation_name)

func _update_facing_direction(dir_x):
	# Определяем, куда должен смотреть враг
	if dir_x > 0:
		facing_right = true
	elif dir_x < 0:
		facing_right = false

	# Проверяем, нужно ли флипать спрайт
	sprite.flip_h = facing_right

func take_damage(amount):
	health -= amount
	health_bar.value = health
	print("Enemy took damage. Health: ", health)
	if health <= 0:
		_die()
	else:
		_update_animation("hurt")

func _die():
	_update_animation("death")
	print("Enemy died")
	queue_free()

func _on_detection_area_body_entered(body):
	if body == player:
		player_detected = true
		state = "chase"

func _on_detection_area_body_exited(body):
	if body == player:
		player_detected = false
		state = "patrol"

func _on_damage_area_entered(area):
	if area.is_in_group("player_attack"):
		var player = area.get_parent()
		take_damage(player.damage)

func _adjust_attack_area_position():
	if attack_area_shape:
		attack_area_shape.position = attack_offset if facing_right else -attack_offset
