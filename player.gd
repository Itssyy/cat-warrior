extends CharacterBody2D

enum State {IDLE, RUN, JUMP, FALL, ATTACK}

@export var speed := 200.0
@export var jump_velocity := -264
@export var attack_duration := 1.2
@export var damage := 10
@export var attack_offset := Vector2(32, 0)
@export var health = 100
@export var max_jumps := 2  # Количество доступных прыжков

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D2
@onready var attack_timer: Timer = $Timer
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var damage_area = $DamageArea

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_state: State = State.IDLE
var is_facing_right := true
var jump_count := 0  # Счётчик прыжков

func _ready() -> void:
	attack_area.add_to_group("player_attack")
	attack_timer = Timer.new()
	attack_timer.one_shot = true
	attack_timer.connect("timeout", Callable(self, "_on_attack_timer_timeout"))
	add_child(attack_timer)
	attack_collision_shape.disabled = true
	damage_area.area_entered.connect(_on_damage_area_entered)

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	
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
	
	move_and_slide()
	update_animation()
	adjust_attack_area_position()  # Обновление позиции области атаки

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func handle_idle_state() -> void:
	velocity.x = 0
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		change_state(State.JUMP)
	elif Input.is_action_just_pressed("attack"):
		change_state(State.ATTACK)
	elif Input.get_axis("ui_left", "ui_right") != 0:
		change_state(State.RUN)

func handle_run_state() -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed
	update_facing_direction(direction)
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		change_state(State.JUMP)
	elif Input.is_action_just_pressed("attack"):
		change_state(State.ATTACK)
	elif is_zero_approx(velocity.x):
		change_state(State.IDLE)

# Изменённая логика для двойного прыжка
func handle_jump_state() -> void:
	# Первый прыжок на земле
	if is_on_floor() and jump_count == 0:
		velocity.y = jump_velocity
		jump_count += 1  # Увеличиваем счётчик прыжков при первом прыжке
	
	# Второй прыжок можно выполнить в воздухе
	elif jump_count < max_jumps and Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_velocity
		jump_count += 1  # Увеличиваем счётчик прыжков при втором прыжке
	
	# Передвижение в воздухе
	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed
	update_facing_direction(direction)

	# Переход в состояние падения, если персонаж начинает падать
	if velocity.y > 0:
		change_state(State.FALL)

func handle_fall_state() -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed
	update_facing_direction(direction)
	
	# Когда персонаж касается пола, сбрасываем счётчик прыжков
	if is_on_floor():
		jump_count = 0  # Сбрасываем прыжки при приземлении
		change_state(State.IDLE)

func handle_attack_state() -> void:
	velocity.x = 0
	if not attack_timer.is_stopped():
		return
	
	attack_timer.start(attack_duration)
	attack_collision_shape.disabled = false
	apply_attack_damage()

func apply_attack_damage() -> void:
	var bodies = attack_area.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("take_damage"):
			body.take_damage(damage)

func _on_attack_timer_timeout() -> void:
	attack_collision_shape.disabled = true
	change_state(State.IDLE)

func change_state(new_state: State) -> void:
	current_state = new_state
	# Можно добавить логику для входа в новое состояние

func update_animation() -> void:
	match current_state:
		State.IDLE:
			animated_sprite.play("idle")
		State.RUN:
			animated_sprite.play("run")
		State.JUMP:
			animated_sprite.play("jump_up")
		State.FALL:
			animated_sprite.play("jump_d")
		State.ATTACK:
			animated_sprite.play("attack")
	
	animated_sprite.flip_h = not is_facing_right

func adjust_attack_area_position() -> void:
	attack_area.position = attack_offset if is_facing_right else -attack_offset

func update_facing_direction(direction: float) -> void:
	if direction > 0:
		is_facing_right = true
	elif direction < 0:
		is_facing_right = false
		
func take_damage(amount):
	health -= amount
	print("Player. Health: ", health)
	if health <= 0:
		queue_free()
	else:
		pass
		
func _on_damage_area_entered(area):
	if area.is_in_group("enemy_attack"):
		var enemy = area.get_parent()
		take_damage(enemy.damage)
