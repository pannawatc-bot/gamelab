extends Node2D

const W := 1280.0
const H := 720.0
const GRAVITY := 1700.0
const MOVE_SPEED := 330.0
const JUMP_SPEED := 650.0
const PLAYER_SIZE := Vector2(38, 58)
const STUDENT_NAME := "นายปัณณวัชร์ เชเดช"
const STUDENT_ID := "673380079-5"
const GAME_STORY := "นักวิ่งแห่งฟากฟ้าต้องรวบรวมคริสตัลพลังงานทั้งสี่เกาะ เพื่อเปิดประตู Skyforge และหยุดกองทัพจักรกลที่ยึดครองนครลอยฟ้า"

enum GameState { MENU, CREDITS, PLAYING, PAUSED, GAME_OVER, WIN }

var state := GameState.MENU
var font: Font
var bg: Texture2D
var sprite_atlas: Texture2D
var rng := RandomNumberGenerator.new()
var player := {"pos": Vector2(120, 540), "vel": Vector2.ZERO, "grounded": false, "face": 1.0}
var platforms: Array[Dictionary] = []
var hazards: Array[Rect2] = []
var enemies: Array[Dictionary] = []
var items: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var portal := Rect2()
var camera_x := 0.0
var level := 1
var level_length := 3600.0
var hp := 5
var max_hp := 5
var score := 0
var crystals := 0
var invulnerable := 0.0
var shoot_cooldown := 0.0
var dash_cooldown := 0.0
var speed_boost := 0.0
var jump_boost := 0.0
var level_time := 0.0
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var button_rects := {
	"play": Rect2(490, 388, 300, 64),
	"credits": Rect2(490, 466, 300, 58),
	"exit": Rect2(490, 538, 300, 58)
}
var theme_colors := [
	Color("#42d9c8"), Color("#d382ff"), Color("#ffb84d"), Color("#ff668c")
]

func _ready() -> void:
	font = load("res://assets/fonts/NotoSansThai.ttf")
	bg = load("res://assets/skyforge_background.png")
	sprite_atlas = load("res://assets/sprites/skyforge_atlas.png")
	rng.randomize()
	_setup_audio()
	if "--qa-gameplay" in OS.get_cmdline_user_args():
		start_game()
	elif "--qa-credits" in OS.get_cmdline_user_args():
		state = GameState.CREDITS
	queue_redraw()

func _setup_audio() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.volume_db = -20.0
	music_player.stream = _make_music()
	music_player.play()
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)

func _make_music() -> AudioStreamWAV:
	var rate := 11025
	var seconds := 8.0
	var count := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var notes := [110.0, 164.81, 220.0, 146.83]
	for i in count:
		var t := float(i) / rate
		var n: float = notes[int(t / 2.0) % notes.size()]
		var pulse := sin(TAU * n * t) * 0.38 + sin(TAU * n * 1.5 * t) * 0.18
		var beat := exp(-fmod(t, 0.5) * 10.0) * sin(TAU * 55.0 * t) * 0.24
		data.encode_s16(i * 2, int(clamp((pulse + beat) * 10500.0, -32767, 32767)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = count
	return wav

func _beep(freq: float, duration: float, volume := -10.0) -> void:
	var rate := 11025
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var env := 1.0 - float(i) / count
		var sample := sin(TAU * freq * t) * env * 15000.0
		data.encode_s16(i * 2, int(sample))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	for p in sfx_players:
		if not p.playing:
			p.volume_db = volume
			p.stream = wav
			p.play()
			break

func start_game() -> void:
	GameManager.reset_game()
	level = 1
	hp = max_hp
	score = 0
	crystals = 0
	state = GameState.PLAYING
	_load_level(level)
	_beep(440, 0.15)

func _load_level(n: int) -> void:
	GameManager.current_level = n
	platforms.clear()
	hazards.clear()
	enemies.clear()
	items.clear()
	bullets.clear()
	particles.clear()
	level_time = 0.0
	level_length = 3300.0 + n * 280.0
	player.pos = Vector2(120, 540)
	player.vel = Vector2.ZERO
	invulnerable = 1.0
	# Broken ground creates genuine platforming gaps.
	var segments := [Rect2(0, 630, 720, 110), Rect2(830, 630, 620, 110), Rect2(1570, 630, 680, 110), Rect2(2380, 630, 540, 110), Rect2(3040, 630, level_length - 3040, 110)]
	for r in segments:
		platforms.append({"rect": r, "kind": "ground", "base": r.position, "phase": 0.0})
	# Hand-authored route, varied by level.
	_add_platform(Rect2(500, 505, 180, 28), "normal")
	_add_platform(Rect2(760, 545, 130, 25), "jump")
	_add_platform(Rect2(1040, 470 - n * 8, 210, 28), "normal")
	_add_platform(Rect2(1320, 390, 170, 26), "moving")
	_add_platform(Rect2(1510, 535, 130, 25), "jump")
	_add_platform(Rect2(1770, 455, 220, 28), "normal")
	_add_platform(Rect2(2080, 360 + n * 12, 170, 26), "moving")
	_add_platform(Rect2(2290, 535, 140, 25), "jump")
	_add_platform(Rect2(2540, 450, 230, 28), "normal")
	_add_platform(Rect2(2820, 355, 180, 26), "moving")
	_add_platform(Rect2(3150, 500, 200, 28), "normal")
	for x in [680.0, 1140.0, 1680.0, 2150.0, 2660.0, 3190.0]:
		hazards.append(Rect2(x + n * 9.0, 604, 74, 26))
	# Enemies: crawler, hopper, drone.
	_spawn_enemy("crawler", Vector2(980, 590), 82 + n * 7)
	_spawn_enemy("hopper", Vector2(1810, 415), 68 + n * 6)
	_spawn_enemy("drone", Vector2(2600, 340), 95 + n * 8)
	_spawn_enemy("crawler", Vector2(3100, 590), 90 + n * 6)
	if n >= 3:
		_spawn_enemy("drone", Vector2(1420, 300), 110)
	if n == 4:
		_spawn_enemy("hopper", Vector2(2720, 590), 100)
	for d in [
		{"type":"crystal", "pos":Vector2(560, 455)},
		{"type":"heart", "pos":Vector2(1110, 425)},
		{"type":"speed", "pos":Vector2(1830, 405)},
		{"type":"jump", "pos":Vector2(2600, 400)},
		{"type":"crystal", "pos":Vector2(2890, 305)},
		{"type":"crystal", "pos":Vector2(3230, 450)}
	]:
		d["taken"] = false
		items.append(d)
	portal = Rect2(level_length - 150, 510, 84, 120)
	camera_x = 0.0
	queue_redraw()

func _add_platform(rect: Rect2, kind: String) -> void:
	platforms.append({"rect": rect, "kind": kind, "base": rect.position, "phase": rng.randf_range(0, TAU)})

func _spawn_enemy(kind: String, pos: Vector2, speed: float) -> void:
	enemies.append({"type":kind, "pos":pos, "spawn":pos, "vel":Vector2(speed if rng.randf() > 0.5 else -speed, 0), "alive":true, "respawn":0.0, "phase":rng.randf_range(0, TAU)})

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.033)
	if state == GameState.PLAYING:
		_update_game(dt)
	queue_redraw()

func _update_game(dt: float) -> void:
	level_time += dt
	invulnerable = max(0.0, invulnerable - dt)
	shoot_cooldown = max(0.0, shoot_cooldown - dt)
	dash_cooldown = max(0.0, dash_cooldown - dt)
	speed_boost = max(0.0, speed_boost - dt)
	jump_boost = max(0.0, jump_boost - dt)
	_update_platforms()
	var axis := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): axis -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): axis += 1.0
	var target_speed := axis * MOVE_SPEED * (1.35 if speed_boost > 0 else 1.0)
	player.vel.x = move_toward(player.vel.x, target_speed, 1800.0 * dt)
	if axis != 0: player.face = sign(axis)
	if (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) and player.grounded:
		player.vel.y = -JUMP_SPEED * (1.28 if jump_boost > 0 else 1.0)
		player.grounded = false
		_beep(520, 0.09, -16)
	player.vel.y += GRAVITY * dt
	var old_pos: Vector2 = player.pos
	player.pos += player.vel * dt
	player.grounded = false
	_resolve_platforms(old_pos)
	player.pos.x = clamp(player.pos.x, 20.0, level_length - 20.0)
	if player.pos.y > 790:
		_damage(2)
		player.pos = Vector2(max(100.0, camera_x + 160.0), 500)
		player.vel = Vector2.ZERO
	_check_hazards()
	_update_items()
	_update_enemies(dt)
	_update_bullets(dt)
	_update_particles(dt)
	if _player_rect().intersects(portal):
		if level < 4:
			level += 1
			score += 500
			_load_level(level)
			_beep(740, 0.22)
		else:
			score += max(0, 2000 - int(level_time * 20.0))
			state = GameState.WIN
			_beep(880, 0.5)
	camera_x = lerp(camera_x, clamp(player.pos.x - 340.0, 0.0, max(0.0, level_length - W)), min(1.0, dt * 5.0))

func _update_platforms() -> void:
	for p in platforms:
		if p.kind == "moving":
			var r: Rect2 = p.rect
			r.position = p.base + Vector2(sin(level_time * 1.25 + p.phase) * 95.0, cos(level_time * 0.9 + p.phase) * 34.0)
			p.rect = r

func _resolve_platforms(old_pos: Vector2) -> void:
	var half: Vector2 = PLAYER_SIZE * 0.5
	var old_bottom: float = old_pos.y + half.y
	var new_bottom: float = float(player.pos.y) + half.y
	for p in platforms:
		var r: Rect2 = p.rect
		if player.vel.y >= 0 and player.pos.x + half.x > r.position.x and player.pos.x - half.x < r.end.x and old_bottom <= r.position.y + 10 and new_bottom >= r.position.y:
			player.pos.y = r.position.y - half.y
			player.vel.y = -820.0 if p.kind == "jump" else 0.0
			player.grounded = p.kind != "jump"
			if p.kind == "jump":
				_beep(700, 0.12)
				_burst(Vector2(player.pos.x, r.position.y), Color("#ffdc66"), 10)
			return

func _check_hazards() -> void:
	for h in hazards:
		if _player_rect().intersects(h):
			_damage(1)
			player.vel.y = -420.0
			player.vel.x = -player.face * 250.0

func _update_items() -> void:
	for item in items:
		if item.taken: continue
		if player.pos.distance_to(item.pos) < 48:
			item.taken = true
			match item.type:
				"crystal": crystals += 1; score += 150
				"heart": hp = min(max_hp, hp + 2); score += 75
				"speed": speed_boost = 10.0; score += 100
				"jump": jump_boost = 10.0; score += 100
			_burst(item.pos, Color("#7df9ff"), 16)
			_beep(920, 0.12)
			GameManager.score = score
			GameManager.crystals = crystals
			GameManager.hp = hp

func _enemy_rect(e: Dictionary) -> Rect2:
	var size := Vector2(48, 40) if e.type != "drone" else Vector2(52, 34)
	return Rect2(e.pos - size * 0.5, size)

func _update_enemies(dt: float) -> void:
	for e in enemies:
		if not e.alive:
			e.respawn -= dt
			if e.respawn <= 0:
				e.alive = true
				e.pos = e.spawn
				e.vel = Vector2(75 if rng.randf() > 0.5 else -75, 0)
			continue
		match e.type:
			"crawler":
				e.pos.x += e.vel.x * dt
				if abs(e.pos.x - e.spawn.x) > 170: e.vel.x *= -1
			"hopper":
				e.phase += dt
				e.pos.x += e.vel.x * dt
				e.pos.y = e.spawn.y - abs(sin(e.phase * 2.1)) * 78
				if abs(e.pos.x - e.spawn.x) > 150: e.vel.x *= -1
			"drone":
				e.phase += dt
				e.pos.x += e.vel.x * dt
				e.pos.y = e.spawn.y + sin(e.phase * 2.4) * 55
				if abs(e.pos.x - e.spawn.x) > 190: e.vel.x *= -1
		if _player_rect().intersects(_enemy_rect(e)):
			var stomp: bool = player.vel.y > 140 and player.pos.y < e.pos.y - 12
			if stomp:
				_kill_enemy(e)
				player.vel.y = -430
			else:
				_damage(1)
				player.vel.x = sign(player.pos.x - e.pos.x) * 360
				player.vel.y = -260

func _kill_enemy(e: Dictionary) -> void:
	e.alive = false
	e.respawn = rng.randf_range(5.0, 8.0)
	score += 250
	GameManager.score = score
	_burst(e.pos, theme_colors[level - 1], 22)
	_beep(190, 0.16)

func _update_bullets(dt: float) -> void:
	for b in bullets:
		b.pos += b.vel * dt
		b.life -= dt
		for e in enemies:
			if e.alive and _enemy_rect(e).has_point(b.pos):
				b.life = 0
				_kill_enemy(e)
	for i in range(bullets.size() - 1, -1, -1):
		if bullets[i].life <= 0 or bullets[i].pos.x < 0 or bullets[i].pos.x > level_length:
			bullets.remove_at(i)

func _update_particles(dt: float) -> void:
	for p in particles:
		p.pos += p.vel * dt
		p.vel.y += 550.0 * dt
		p.life -= dt
	for i in range(particles.size() - 1, -1, -1):
		if particles[i].life <= 0: particles.remove_at(i)

func _burst(pos: Vector2, color: Color, amount: int) -> void:
	for i in amount:
		var a := rng.randf_range(0, TAU)
		var sp := rng.randf_range(80, 260)
		particles.append({"pos":pos, "vel":Vector2(cos(a), sin(a)) * sp, "life":rng.randf_range(0.3, 0.8), "color":color})

func _damage(amount: int) -> void:
	if invulnerable > 0: return
	hp -= amount
	GameManager.hp = hp
	invulnerable = 1.25
	_beep(110, 0.22)
	_burst(player.pos, Color("#ff4e6a"), 15)
	if hp <= 0:
		state = GameState.GAME_OVER

func _player_rect() -> Rect2:
	return Rect2(player.pos - PLAYER_SIZE * 0.5, PLAYER_SIZE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if state == GameState.PLAYING: state = GameState.PAUSED
			elif state == GameState.PAUSED: state = GameState.PLAYING
			elif state != GameState.MENU: state = GameState.MENU
		if state == GameState.PLAYING:
			if event.keycode == KEY_J or event.keycode == KEY_F:
				_shoot()
			elif event.keycode == KEY_K or event.keycode == KEY_SHIFT:
				_dash()
		elif state == GameState.MENU and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			start_game()
		elif state == GameState.GAME_OVER and event.keycode == KEY_R:
			hp = max_hp; _load_level(level); state = GameState.PLAYING
		elif state == GameState.WIN and event.keycode == KEY_ENTER:
			state = GameState.MENU
		elif state == GameState.PAUSED and event.keycode == KEY_Q:
			state = GameState.MENU
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == GameState.MENU:
			if button_rects.play.has_point(event.position): start_game()
			elif button_rects.credits.has_point(event.position): state = GameState.CREDITS
			elif button_rects.exit.has_point(event.position): get_tree().quit()
		elif state in [GameState.CREDITS, GameState.GAME_OVER, GameState.WIN]:
			state = GameState.MENU

func _shoot() -> void:
	if shoot_cooldown > 0: return
	shoot_cooldown = 0.28
	bullets.append({"pos":player.pos + Vector2(player.face * 30, -5), "vel":Vector2(player.face * 760, 0), "life":1.4})
	_beep(680, 0.07, -14)

func _dash() -> void:
	if dash_cooldown > 0: return
	dash_cooldown = 1.2
	player.vel.x = player.face * 760.0
	invulnerable = max(invulnerable, 0.22)
	_beep(320, 0.08, -15)

func _draw() -> void:
	_draw_background()
	if state == GameState.MENU: _draw_menu()
	elif state == GameState.CREDITS: _draw_credits()
	elif state in [GameState.PLAYING, GameState.PAUSED]:
		_draw_world()
		_draw_hud()
		if state == GameState.PAUSED: _draw_pause()
	elif state == GameState.GAME_OVER:
		_draw_world(); _draw_end(false)
	elif state == GameState.WIN:
		_draw_world(); _draw_end(true)

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("#11182f"))
	if bg:
		var bw := 1920.0
		var off := -fmod(camera_x * 0.12, bw)
		draw_texture_rect(bg, Rect2(off, 0, bw, H), false, Color(0.78, 0.82, 0.95))
		draw_texture_rect(bg, Rect2(off + bw, 0, bw, H), false, Color(0.78, 0.82, 0.95))
	# Near parallax mist.
	for i in 9:
		var x := fmod(i * 230.0 - camera_x * 0.28, W + 300.0) - 100.0
		draw_circle(Vector2(x, 610 + sin(i * 2.0) * 18), 120, Color(0.55, 0.72, 0.9, 0.10))

func _draw_menu() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.035, 0.09, 0.38))
	_round_rect(Rect2(380, 78, 520, 548), Color(0.025, 0.045, 0.12, 0.93), 30, Color(0.40, 0.96, 0.90, 0.75), 2)
	_text("SKYFORGE", Vector2(640, 180), 58, Color("#ffffff"), true)
	_text("RUNNER", Vector2(640, 238), 46, Color("#67f5e5"), true)
	_text("ผจญภัยเหนือหมู่เกาะลอยฟ้า", Vector2(640, 292), 24, Color("#dbe9ff"), true)
	for key in ["play", "credits", "exit"]:
		var r: Rect2 = button_rects[key]
		var hover := r.has_point(get_local_mouse_position())
		_round_rect(r, Color("#5d62d6") if hover else Color(0.08, 0.13, 0.29, 0.96), 18, Color(0.45, 0.95, 0.94, 0.85), 2)
	var labels := {"play":"เริ่มเกม", "credits":"เครดิต", "exit":"ออกจากเกม"}
	for key in labels: _text(labels[key], button_rects[key].get_center() + Vector2(0, 9), 25, Color.WHITE, true)
	_text("ENTER เริ่มเกม  •  เล่นด้วยคีย์บอร์ด", Vector2(640, 662), 18, Color("#cbd7ed"), true)

func _draw_credits() -> void:
	_round_rect(Rect2(260, 105, 760, 510), Color(0.025, 0.045, 0.12, 0.95), 34, Color(0.66, 0.55, 1.0, 0.70), 2)
	draw_circle(Vector2(640, 170), 34, Color(0.35, 0.32, 0.82, 0.55))
	draw_circle(Vector2(640, 170), 22, Color("#7df9ff"), false, 4)
	draw_circle(Vector2(640, 170), 7, Color("#ffda72"))
	_text("SKYFORGE RUNNER", Vector2(640, 246), 34, Color.WHITE, true)
	_text("CREATED BY", Vector2(640, 282), 14, Color("#7df9ff"), true)
	_text(STUDENT_NAME, Vector2(640, 328), 27, Color("#f2f6ff"), true)
	_text(STUDENT_ID, Vector2(640, 361), 18, Color("#aebbd5"), true)
	var chips := [
		{"rect":Rect2(345, 414, 170, 46), "text":"4 LEVELS"},
		{"rect":Rect2(555, 414, 170, 46), "text":"3 ENEMIES"},
		{"rect":Rect2(765, 414, 170, 46), "text":"GODOT 4"}
	]
	for chip in chips:
		_round_rect(chip.rect, Color(0.12, 0.17, 0.34, 0.94), 18, Color(0.48, 0.90, 0.93, 0.42), 1)
		_text(chip.text, chip.rect.get_center() + Vector2(0, 6), 15, Color("#dce9ff"), true)
	_text("2D PLATFORM ADVENTURE", Vector2(640, 512), 17, Color("#ffda72"), true)
	_text("คลิกหรือกด ESC เพื่อกลับ", Vector2(640, 570), 17, Color("#9facc8"), true)

func _draw_world() -> void:
	var accent: Color = theme_colors[level - 1]
	for p in platforms:
		var r: Rect2 = _screen_rect(p.rect)
		if r.end.x < -50 or r.position.x > W + 50: continue
		var c := accent.darkened(0.45) if p.kind == "ground" else accent.darkened(0.25)
		draw_rect(r, Color(0.03, 0.06, 0.13, 0.96), true)
		draw_rect(Rect2(r.position, Vector2(r.size.x, min(8.0, r.size.y))), c.lightened(0.2), true)
		draw_rect(r, c, false, 2)
		if p.kind == "moving":
			for x in range(int(r.position.x + 18), int(r.end.x - 8), 28): draw_circle(Vector2(x, r.position.y + 13), 4, Color("#ffe681"))
		elif p.kind == "jump":
			draw_colored_polygon(PackedVector2Array([Vector2(r.position.x+12,r.end.y),Vector2(r.get_center().x,r.position.y+4),Vector2(r.end.x-12,r.end.y)]), Color("#ffcf4d"))
	for h in hazards:
		var r := _screen_rect(h)
		for x in range(int(r.position.x), int(r.end.x), 18):
			draw_colored_polygon(PackedVector2Array([Vector2(x,r.end.y),Vector2(x+9,r.position.y),Vector2(x+18,r.end.y)]), Color("#ff557d"))
	# Portal.
	var pr := _screen_rect(portal)
	draw_arc(pr.get_center(), 39, 0, TAU, 40, accent, 8)
	draw_arc(pr.get_center(), 29 + sin(level_time*4)*3, 0, TAU, 32, Color.WHITE, 3)
	_text("EXIT", Vector2(pr.get_center().x, pr.position.y - 12), 14, Color.WHITE, true)
	for item in items:
		if item.taken: continue
		var q: Vector2 = _screen(item.pos + Vector2(0, sin(level_time*3 + item.pos.x)*5))
		match item.type:
			"crystal":
				draw_colored_polygon(PackedVector2Array([q+Vector2(0,-18),q+Vector2(13,0),q+Vector2(0,20),q+Vector2(-13,0)]), Color("#70f8ff"))
			"heart":
				draw_circle(q+Vector2(-8,-3),10,Color("#ff5d78")); draw_circle(q+Vector2(8,-3),10,Color("#ff5d78")); draw_colored_polygon(PackedVector2Array([q+Vector2(-17,1),q+Vector2(17,1),q+Vector2(0,22)]),Color("#ff5d78"))
			"speed": _draw_item_orb(q, Color("#ffce66"), "S")
			"jump": _draw_item_orb(q, Color("#b58aff"), "J")
	for e in enemies:
		if e.alive: _draw_enemy(e)
	for b in bullets:
		var q := _screen(b.pos)
		draw_circle(q, 8, Color("#ecfbff")); draw_circle(q, 13, Color(0.3,0.95,1,0.25))
	for p in particles:
		draw_circle(_screen(p.pos), max(1.0, p.life * 7.0), p.color)
	_draw_player()

func _draw_player() -> void:
	var q := _screen(player.pos)
	var flash := invulnerable > 0 and int(invulnerable * 12) % 2 == 0
	if flash: return
	if sprite_atlas:
		var frame := 0
		if not player.grounded: frame = 3
		elif absf(player.vel.x) > 40.0: frame = 1 + int(level_time * 8.0) % 2
		var dst := Rect2(q - Vector2(42, 45), Vector2(84, 84))
		var src := Rect2(frame * 313, 0, 313, 313)
		draw_texture_rect_region(sprite_atlas, dst, src)
		return
	# Scarf and body.
	draw_colored_polygon(PackedVector2Array([q+Vector2(-player.face*5,-15),q+Vector2(-player.face*34,-5),q+Vector2(-player.face*10,5)]), Color("#ffcf5a"))
	draw_circle(q+Vector2(0,-21), 15, Color("#eaf8ff"))
	draw_rect(Rect2(q+Vector2(-16,-9), Vector2(32,34)), Color("#3658b9"), true)
	draw_rect(Rect2(q+Vector2(-12,20), Vector2(9,12)), Color("#172348"), true)
	draw_rect(Rect2(q+Vector2(4,20), Vector2(9,12)), Color("#172348"), true)
	draw_rect(Rect2(q+Vector2(player.face*3,-25), Vector2(player.face*9,5)), Color("#67f5e5"), true)
	draw_circle(q+Vector2(0,-21), 19, Color("#7df9ff"), false, 2)

func _draw_enemy(e: Dictionary) -> void:
	var q := _screen(e.pos)
	if sprite_atlas:
		var row: int = {"crawler":1, "hopper":2, "drone":3}[e.type]
		var frame := int(level_time * 7.0 + e.phase) % 4
		var size := Vector2(88, 88) if e.type != "drone" else Vector2(78, 78)
		draw_texture_rect_region(sprite_atlas, Rect2(q-size*0.5,size), Rect2(frame*313,row*313,313,313))
		return
	match e.type:
		"crawler":
			draw_rect(Rect2(q-Vector2(24,17),Vector2(48,34)),Color("#ff6b7f"),true)
			for x in [-16,0,16]: draw_circle(q+Vector2(x,18),7,Color("#341b3f"))
			draw_circle(q+Vector2(sign(e.vel.x)*12,-5),5,Color.WHITE)
		"hopper":
			draw_colored_polygon(PackedVector2Array([q+Vector2(0,-25),q+Vector2(25,14),q+Vector2(0,22),q+Vector2(-25,14)]),Color("#ffbf4d"))
			draw_circle(q+Vector2(0,-4),7,Color("#3a2453"))
		"drone":
			draw_circle(q,21,Color("#b17dff")); draw_arc(q,28,0,TAU,20,Color("#74f7ff"),4)
			draw_circle(q+Vector2(sign(e.vel.x)*8,-3),5,Color.WHITE)

func _draw_item_orb(q: Vector2, color: Color, label: String) -> void:
	draw_circle(q,18,Color(color,0.28)); draw_circle(q,13,color); _text(label,q+Vector2(0,7),16,Color("#142044"),true)

func _draw_hud() -> void:
	draw_rect(Rect2(18, 16, 520, 82), Color(0.02, 0.04, 0.11, 0.86), true)
	draw_rect(Rect2(18, 16, 520, 82), theme_colors[level-1], false, 2)
	for i in max_hp:
		var c := Color("#ff5775") if i < hp else Color(0.25,0.28,0.38,0.8)
		draw_circle(Vector2(42+i*30,44),10,c)
	_text("SCORE  %06d" % score, Vector2(205, 49), 21, Color.WHITE)
	_text("◆ %02d" % crystals, Vector2(405, 49), 21, Color("#75f7ff"))
	_text("LEVEL %d / 4" % level, Vector2(40, 82), 17, theme_colors[level-1])
	_text("A/D เดิน  SPACE กระโดด  J ยิง  K พุ่ง  ESC พัก", Vector2(210, 80), 15, Color("#cdd8ef"))
	if speed_boost > 0: _text("SPEED %.0f" % speed_boost, Vector2(1070,45),17,Color("#ffcf75"))
	if jump_boost > 0: _text("JUMP %.0f" % jump_boost, Vector2(1070,70),17,Color("#d4b0ff"))

func _draw_pause() -> void:
	draw_rect(Rect2(0,0,W,H),Color(0,0,0,0.58),true)
	_text("หยุดเกมชั่วคราว",Vector2(640,310),44,Color.WHITE,true)
	_text("ESC เล่นต่อ   •   Q กลับเมนู",Vector2(640,372),22,Color("#7df9ff"),true)

func _draw_end(won: bool) -> void:
	draw_rect(Rect2(0,0,W,H),Color(0.01,0.02,0.07,0.72),true)
	var title := "ภารกิจสำเร็จ!" if won else "พลังชีวิตหมด"
	var col := Color("#7df9ff") if won else Color("#ff6887")
	_text(title,Vector2(640,265),58,col,true)
	_text("คะแนนรวม  %06d" % score,Vector2(640,335),28,Color.WHITE,true)
	_text("คริสตัลที่เก็บได้  %d" % crystals,Vector2(640,378),22,Color("#dbe9ff"),true)
	_text("ENTER / คลิก เพื่อกลับเมนู" if won else "กด R เพื่อลองด่านนี้ใหม่  •  ESC กลับเมนู",Vector2(640,460),20,Color("#ffdd7a"),true)

func _screen(world_pos: Vector2) -> Vector2:
	return world_pos - Vector2(camera_x, 0)

func _screen_rect(r: Rect2) -> Rect2:
	return Rect2(_screen(r.position), r.size)

func _text(text: String, pos: Vector2, size: int, color := Color.WHITE, centered := false) -> void:
	var p := pos
	if centered:
		p.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _round_rect(rect: Rect2, color: Color, radius: int, border_color := Color.TRANSPARENT, border_width := 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border_width > 0:
		style.border_color = border_color
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
	draw_style_box(style, rect)
