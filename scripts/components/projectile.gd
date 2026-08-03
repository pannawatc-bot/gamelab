extends Area2D

@export var speed := 760.0
var direction := 1.0

func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	if absf(position.x) > 5000.0: queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("defeat"): body.defeat()
	queue_free()

