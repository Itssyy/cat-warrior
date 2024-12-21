extends Area2D

var direction = Vector2.ZERO
var speed = 200.0
@export var damage = 10

func _ready():
	# Подключаем сигнал столкновения
	body_entered.connect(_on_body_entered)
	
	# Удаляем снаряд через 3 секунды если он ни с чем не столкнулся
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(queue_free)

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
