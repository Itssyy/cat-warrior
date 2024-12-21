extends Area2D

@export var ability_type := "shoot"  # Тип способности, которую даёт предмет

@onready var animated_sprite = $AnimatedSprite2D
@onready var prompt_label = $Label  # Простой Label для отображения "E"

var player_in_range = false
var current_player = null

func _ready():
	# Подключаем сигналы
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Запускаем анимацию предмета
	if animated_sprite:
		animated_sprite.play("default")
	# Настраиваем и скрываем лейбл
	if prompt_label:
		prompt_label.text = "E"
		prompt_label.visible = false
		prompt_label.position.y = -32  # Размещаем над предметом

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):  # E key
		collect_item()

func _on_body_entered(body: Node2D):
	if body.has_method("unlock_shoot_ability"):
		player_in_range = true
		current_player = body
		if prompt_label:
			prompt_label.visible = true

func _on_body_exited(body: Node2D):
	if body == current_player:
		player_in_range = false
		current_player = null
		if prompt_label:
			prompt_label.visible = false

func collect_item():
	if current_player and current_player.has_method("unlock_shoot_ability"):
		current_player.unlock_shoot_ability()
		# Анимация подбора
		if prompt_label:
			prompt_label.visible = false
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
		tween.tween_callback(queue_free)
