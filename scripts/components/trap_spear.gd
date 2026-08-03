extends StaticBody2D

func _ready() -> void:
	await get_tree().create_timer(randf_range(0.0, 1.8)).timeout
	$AnimationPlayer.play("push")

