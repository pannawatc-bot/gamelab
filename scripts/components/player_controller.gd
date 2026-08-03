extends CharacterBody2D

signal shot(origin: Vector2, direction: float)

@export var move_speed := 330.0
@export var jump_speed := 650.0
@export var gravity := 1700.0
var facing := 1.0

func _physics_process(delta: float) -> void:
	var axis := Input.get_axis("ui_left", "ui_right")
	velocity.x = move_toward(velocity.x, axis * move_speed, 1800.0 * delta)
	if axis != 0.0:
		facing = signf(axis)
		$AnimatedSprite2D.flip_h = facing < 0.0
	if not is_on_floor():
		velocity.y += gravity * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = -jump_speed
	if not is_on_floor():
		$AnimatedSprite2D.play("jump")
	elif absf(velocity.x) > 20.0:
		$AnimatedSprite2D.play("run")
	else:
		$AnimatedSprite2D.play("idle")
	move_and_slide()

