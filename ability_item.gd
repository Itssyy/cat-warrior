extends Area2D

@export var ability_type := "shoot"  # Тип способности, которую даёт предмет

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	# Подключаем сигнал
	body_entered.connect(_on_body_entered)
	# Запускаем анимацию
	if animated_sprite:
		animated_sprite.play("default")
	# Для отладки
	print("Ability item ready!")

func _on_body_entered(body: Node2D):
	print("Body entered: ", body.name)  # Для отладки
	if body.has_method("unlock_shoot_ability"):
		print("Unlocking shoot ability!")  # Для отладки
		body.unlock_shoot_ability()
		# Добавляем анимацию подбора предмета
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
		tween.tween_callback(queue_free)

# Добавляем функцию для визуальной отладки
func _draw():
	# Рисуем красный круг вокруг области коллизии (для отладки)
	draw_circle(Vector2.ZERO, 10, Color(1, 0, 0, 0.2))
