extends CharacterBody2D

@export_enum("crawler", "hopper", "drone") var enemy_type := "crawler"
@export var speed := 80.0
@export var gravity := 1700.0
var direction := -1.0
var spawn_point := Vector2.ZERO
var phase := 0.0

func _ready() -> void:
	spawn_point = global_position
	$AnimatedSprite2D.play("move")

func _physics_process(delta: float) -> void:
	phase += delta
	velocity.x = direction * speed
	if enemy_type == "drone":
		global_position.y = spawn_point.y + sin(phase * 2.3) * 42.0
		if absf(global_position.x - spawn_point.x) > 180.0: direction *= -1.0
	else:
		if not is_on_floor(): velocity.y += gravity * delta
		if enemy_type == "hopper" and is_on_floor() and fmod(phase, 1.8) < delta: velocity.y = -420.0
		if is_on_wall() or absf(global_position.x - spawn_point.x) > 170.0: direction *= -1.0
	$AnimatedSprite2D.flip_h = direction > 0.0
	move_and_slide()

func defeat() -> void:
	$Explosion.emitting = true
	$AnimatedSprite2D.hide()
	set_physics_process(false)
	await get_tree().create_timer(0.8).timeout
	queue_free()

