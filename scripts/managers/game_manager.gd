extends Node

signal hp_changed(value: int, maximum: int)
signal score_changed(value: int)
signal crystals_changed(value: int)

var max_hp := 5
var hp := 5
var score := 0
var crystals := 0
var current_level := 1

func reset_game() -> void:
	hp = max_hp
	score = 0
	crystals = 0
	current_level = 1
	hp_changed.emit(hp, max_hp)
	score_changed.emit(score)
	crystals_changed.emit(crystals)

func damage(amount := 1) -> bool:
	hp = maxi(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	return hp <= 0

func heal(amount := 1) -> void:
	hp = mini(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)

func add_score(amount := 100) -> void:
	score += amount
	score_changed.emit(score)

func add_crystal() -> void:
	crystals += 1
	crystals_changed.emit(crystals)

