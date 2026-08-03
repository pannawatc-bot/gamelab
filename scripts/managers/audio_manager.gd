extends Node

var players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)

func play_sfx(freq := 440.0, duration := 0.12, volume_db := -12.0) -> void:
	var rate := 11025
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var envelope := 1.0 - float(i) / count
		bytes.encode_s16(i * 2, int(sin(TAU * freq * t) * envelope * 14500.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	for player in players:
		if not player.playing:
			player.volume_db = volume_db
			player.stream = wav
			player.play()
			return

