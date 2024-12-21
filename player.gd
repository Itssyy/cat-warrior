extends CharacterBody2D

enum State {IDLE, RUN, JUMP, FALL, ATTACK, SHOOT}

@export var speed := 170.0
@export var jump_velocity := -264
@export var attack_duration := 1.2
@export var shoot_duration := 0.8
@export var damage := 10
@export var attack_offset := Vector2(32, 0)
@export var health = 100
@export var max_jumps := 2
@export var invulnerability_duration := 1.0
@export var blink_interval := 0.1
@export var death_fall_threshold := 600
@export var camera_shake_strength := 2.0  # Сила тряски
@export var camera_shake_duration := 0.2  # Длительность тряски

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D2
@onready var attack_timer: Timer = $Timer
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var damage_area = $DamageArea
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var invulnerability_timer: Timer = Timer.new()
@onready var blink_timer: Timer = Timer.new()
@onready var health_bar: ProgressBar = $UI/HealthBar

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_state: State = State.IDLE
var is_facing_right := true
var jump_count := 0
var is_invulnerable := false
var has_shoot_ability := false

func _ready() -> void:
	attack_area.add_to_group("player_attack")
	attack_timer.one_shot = true
	attack_timer.connect("timeout", Callable(self, "_on_attack_timer_timeout"))

	attack_collision_shape.disabled = true
	damage_area.area_entered.connect(_on_damage_area_entered)
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	
	# Подключаем сигналы анимации
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_frame_changed)

	invulnerability_timer.one_shot = true
	invulnerability_timer.connect("timeout", Callable(self, "_on_invulnerability_timer_timeout"))
	add_child(invulnerability_timer)

	blink_timer.wait_time = blink_interval
	blink_timer.connect("timeout", Callable(self, "_on_blink_timer_timeout"))
	add_child(blink_timer)
	
	health_bar.max_value = health
	health_bar.value = health

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	move_and_slide()

	if global_position.y > death_fall_threshold:
		take_damage(health)
		return

	match current_state:
		State.IDLE:
			handle_idle_state()
		State.RUN:
			handle_run_state()
		State.JUMP:
			handle_jump_state()
		State.FALL:
			handle_fall_state()
		State.ATTACK:
			handle_attack_state()
		State.SHOOT:
			handle_shoot_state()

	update_animation()
	adjust_attack_area_position()

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func _handle_input() -> void:
	if Input.is_action_just_pressed("ui_accept") and (is_on_floor() or jump_count < max_jumps):
		change_state(State.JUMP)
	elif Input.is_action_just_pressed("attack"):
		change_state(State.ATTACK)
	elif Input.is_action_just_pressed("secondary_attack") and has_shoot_ability:
		change_state(State.SHOOT)

func handle_idle_state() -> void:
	velocity.x = 0
	_handle_input()
	if Input.get_axis("ui_left", "ui_right") != 0:
		change_state(State.RUN)

func handle_run_state() -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed
	update_facing_direction(direction)
	_handle_input()
	if is_zero_approx(velocity.x):
		change_state(State.IDLE)

func handle_jump_state() -> void:
	if is_on_floor():
		reset_jumps()

	if Input.is_action_just_pressed("ui_accept") and jump_count < max_jumps:
		velocity.y = jump_velocity
		jump_count += 1

	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed
	update_facing_direction(direction)

	if velocity.y > 0:
		change_state(State.FALL)

func handle_fall_state() -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed
	update_facing_direction(direction)

	if is_on_floor():
		reset_jumps()
		change_state(State.IDLE)

func handle_attack_state() -> void:
	velocity.x = 0
	if not attack_timer.is_stopped():
		return
	
	attack_timer.wait_time = attack_duration
	attack_timer.start()
	update_animation("attack")

func handle_shoot_state() -> void:
	velocity.x = 0
	if not attack_timer.is_stopped():
		return
	
	attack_timer.wait_time = shoot_duration
	attack_timer.start()
	update_animation("shoot")
	shake_camera()  # Добавляем тряску при выстреле

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	match current_state:
		State.JUMP:
			if is_on_floor():
				velocity.y = jump_velocity
				jump_count = 1

			elif jump_count < max_jumps:
				velocity.y = jump_velocity
				jump_count += 1
		State.ATTACK:
			pass
		State.SHOOT:
			pass

func update_animation(anim_name := "") -> void:
	var animation := anim_name
	
	if animation == "":
		match current_state:
			State.IDLE:
				animation = "idle"
			State.RUN:
				animation = "run"
			State.JUMP:
				animation = "jump_up"
			State.FALL:
				animation = "jump_d"
			State.ATTACK:
				if not attack_timer.is_stopped():
					animation = "attack"
				else:
					animation = "idle"
			State.SHOOT:
				if not attack_timer.is_stopped():
					animation = "shoot"
				else:
					animation = "idle"
	
	if animation != animated_sprite.animation:
		animated_sprite.play(animation)
	animated_sprite.flip_h = not is_facing_right

func _on_attack_timer_timeout() -> void:
	if current_state == State.ATTACK or current_state == State.SHOOT:
		change_state(State.IDLE)

func adjust_attack_area_position() -> void:
	attack_area.position = attack_offset if is_facing_right else -attack_offset

func update_facing_direction(direction: float) -> void:
	if direction > 0:
		is_facing_right = true
	elif direction < 0:
		is_facing_right = false

func take_damage(amount):
	if is_invulnerable:
		return

	health -= amount
	health_bar.value = health
	print("Player. Health: ", health)

	if health <= 0:
		get_tree().reload_current_scene()
	else:
		is_invulnerable = true
		invulnerability_timer.start(invulnerability_duration)
		blink_timer.start()
		animated_sprite.modulate = Color("red")
		await get_tree().create_timer(0.2).timeout
		animated_sprite.modulate = Color("white")

func _on_damage_area_entered(area):
	if area.is_in_group("enemy_attack"):
		var enemy = area.get_parent()
		take_damage(enemy.damage)

func reset_jumps() -> void:
	jump_count = 0

func _on_attack_area_body_entered(body: Node2D) -> void:
	if current_state == State.ATTACK and body.has_method("take_damage"):
		body.take_damage(damage)

func _on_invulnerability_timer_timeout():
	is_invulnerable = false
	blink_timer.stop()
	animated_sprite.visible = true

func _on_blink_timer_timeout():
	animated_sprite.visible = not animated_sprite.visible

func unlock_shoot_ability() -> void:
	has_shoot_ability = true
	print("Shoot ability unlocked! Player position: ", global_position)
	# Добавляем визуальный эффект
	animated_sprite.modulate = Color(1, 1, 0)  # Желтая вспышка
	await get_tree().create_timer(0.2).timeout
	animated_sprite.modulate = Color(1, 1, 1)  # Возвращаем нормальный цвет

func _on_frame_changed():
	if current_state == State.ATTACK:
		var frame = animated_sprite.frame
		attack_collision_shape.disabled = not (frame in [2, 3])
	elif current_state == State.SHOOT:
		var frame = animated_sprite.frame
		attack_collision_shape.disabled = not (frame in [1, 2])

func _on_animation_finished():
	if current_state == State.ATTACK or current_state == State.SHOOT:
		attack_collision_shape.disabled = true

func shake_camera() -> void:
	var camera = get_node_or_null("Camera2D")
	if not camera:
		return
		
	var tween = create_tween()
	var start_pos = camera.offset
	
	# Создаем несколько случайных позиций для тряски
	for i in range(10):
		var rand_offset = Vector2(
			randf_range(-camera_shake_strength, camera_shake_strength),
			randf_range(-camera_shake_strength, camera_shake_strength)
		)
		tween.tween_property(camera, "offset", rand_offset, camera_shake_duration / 10.0)
	
	# Возвращаем камеру в исходное положение
	tween.tween_property(camera, "offset", Vector2.ZERO, camera_shake_duration / 10.0)
