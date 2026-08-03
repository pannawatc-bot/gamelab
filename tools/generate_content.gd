extends SceneTree

const TILE_SIZE := Vector2i(64, 64)
const ATLAS_CELL := 313

func _initialize() -> void:
	call_deferred("generate")

func generate() -> void:
	var tile_texture: Texture2D = load("res://assets/tiles/skyforge_tiles.svg")
	var sprite_texture: Texture2D = load("res://assets/sprites/skyforge_atlas.png")
	if tile_texture == null or sprite_texture == null:
		push_error("Import assets first, then rerun generator")
		quit(1)
		return
	var tileset := _make_tileset(tile_texture)
	ResourceSaver.save(tileset, "res://assets/tiles/skyforge_tileset.tres")
	for level_number in range(1, 5):
		_make_level(level_number, tileset)
	_make_character_scene("Player", 0, "res://scenes/player.tscn", sprite_texture, true, "")
	_make_character_scene("Crawler", 1, "res://scenes/enemy_crawler.tscn", sprite_texture, false, "crawler")
	_make_character_scene("Hopper", 2, "res://scenes/enemy_hopper.tscn", sprite_texture, false, "hopper")
	_make_character_scene("Drone", 3, "res://scenes/enemy_drone.tscn", sprite_texture, false, "drone")
	_make_traps()
	_make_projectile()
	_make_items()
	_make_ui_scenes()
	print("Generated TileSet, four levels, character scenes, traps, and UI scenes")
	quit()

func _make_tileset(texture: Texture2D) -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = TILE_SIZE
	tileset.add_physics_layer()
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = TILE_SIZE
	tileset.add_source(source, 0)
	for i in 4:
		source.create_tile(Vector2i(i, 0))
		var data := source.get_tile_data(Vector2i(i, 0), 0)
		data.add_collision_polygon(0)
		if i == 2:
			data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-32,32), Vector2(0,-22), Vector2(32,32)]))
		else:
			data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-32,-32), Vector2(32,-32), Vector2(32,32), Vector2(-32,32)]))
	return tileset

func _make_level(number: int, tileset: TileSet) -> void:
	var root := Node2D.new()
	root.name = "Level%02d" % number
	root.set_meta("level_number", number)
	root.set_meta("story", "Collect Sky Crystals and reach the portal across the floating ruins.")
	var parallax := Parallax2D.new()
	parallax.name = "Parallax2D"
	parallax.repeat_size = Vector2(1920, 720)
	parallax.scroll_scale = Vector2(0.15, 0.15)
	root.add_child(parallax)
	parallax.owner = root
	var backdrop := Sprite2D.new()
	backdrop.name = "SkyforgeBackground"
	backdrop.texture = load("res://assets/skyforge_background.png")
	backdrop.centered = false
	backdrop.scale = Vector2(0.94, 0.94)
	parallax.add_child(backdrop)
	backdrop.owner = root
	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = tileset
	root.add_child(layer)
	layer.owner = root
	var gaps: Array = [[11,12], [15,16], [20,21], [25,26]][number - 1]
	for x in 58:
		if x not in gaps:
			layer.set_cell(Vector2i(x, 9), 0, Vector2i((number - 1) % 2, 0), 0)
	for x in range(8, 12): layer.set_cell(Vector2i(x, 7), 0, Vector2i(1, 0), 0)
	for x in range(17, 21): layer.set_cell(Vector2i(x, 6), 0, Vector2i(1, 0), 0)
	for x in range(27, 31): layer.set_cell(Vector2i(x, 5), 0, Vector2i(1, 0), 0)
	layer.set_cell(Vector2i(13 + number, 8), 0, Vector2i(2, 0), 0)
	layer.set_cell(Vector2i(22 + number, 8), 0, Vector2i(3, 0), 0)
	var marker := Marker2D.new()
	marker.name = "PlayerSpawn"
	marker.position = Vector2(128, 500)
	root.add_child(marker)
	marker.owner = root
	var exit := Marker2D.new()
	exit.name = "PortalSpawn"
	exit.position = Vector2(3550, 500)
	root.add_child(exit)
	exit.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://levels/level_%02d.tscn" % number)
	root.free()

func _atlas_frame(texture: Texture2D, row: int, column: int) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(column * ATLAS_CELL, row * ATLAS_CELL, ATLAS_CELL, ATLAS_CELL)
	return frame

func _make_character_scene(node_name: String, row: int, path: String, texture: Texture2D, player: bool, enemy_kind: String) -> void:
	var root: CharacterBody2D = CharacterBody2D.new()
	root.name = node_name
	root.add_to_group("Player" if player else "Enemies")
	root.set_script(load("res://scripts/components/player_controller.gd") if player else load("res://scripts/components/enemy_ai.gd"))
	if not player:
		root.set("enemy_type", enemy_kind)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in (["idle", "run", "jump"] if player else ["move"]):
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 7.0)
		frames.set_animation_loop(anim, true)
	if player:
		frames.add_frame("idle", _atlas_frame(texture, row, 0))
		frames.add_frame("run", _atlas_frame(texture, row, 1))
		frames.add_frame("run", _atlas_frame(texture, row, 2))
		frames.add_frame("jump", _atlas_frame(texture, row, 3))
	else:
		for column in 4: frames.add_frame("move", _atlas_frame(texture, row, column))
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = frames
	sprite.animation = "idle" if player else "move"
	sprite.scale = Vector2(0.24, 0.24)
	root.add_child(sprite)
	sprite.owner = root
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := CapsuleShape2D.new()
	shape.radius = 18.0 if player else 22.0
	shape.height = 58.0 if player else 46.0
	collision.shape = shape
	root.add_child(collision)
	collision.owner = root
	if not player:
		var particles := GPUParticles2D.new()
		particles.name = "Explosion"
		particles.amount = 28
		particles.lifetime = 0.7
		particles.one_shot = true
		particles.emitting = false
		var material := ParticleProcessMaterial.new()
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		material.emission_sphere_radius = 12.0
		material.initial_velocity_min = 90.0
		material.initial_velocity_max = 240.0
		material.gravity = Vector3(0, 420, 0)
		material.color = [Color("#ff6b7f"), Color("#ffbf4d"), Color("#9b70ff")][row - 1]
		particles.process_material = material
		root.add_child(particles)
		particles.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, path)
	root.free()

func _make_traps() -> void:
	_make_spear()
	_make_simple_trap("Pendulum", "res://scenes/trap_pendulum.tscn", Color("#7c6a91"), true, "Traps")
	_make_simple_trap("Shuriken", "res://scenes/trap_shuriken.tscn", Color("#c5e7ff"), false, "Traps")
	_make_simple_trap("MovingPlatform", "res://scenes/moving_platform.tscn", Color("#7df9ff"), false, "Platforms")
	_make_simple_trap("Elevator", "res://scenes/elevator.tscn", Color("#d59aff"), false, "Platforms")
	_make_simple_trap("JumpPad", "res://scenes/jump_pad.tscn", Color("#ffdf70"), false, "JumpPads")
	_make_simple_trap("PortalGate", "res://scenes/portal_gate.tscn", Color("#79f7ff"), false, "Portals")

func _make_spear() -> void:
	var root := StaticBody2D.new()
	root.name = "TrapSpear"
	root.add_to_group("Traps")
	root.set_script(load("res://scripts/components/trap_spear.gd"))
	var spear := Polygon2D.new()
	spear.name = "Spear"
	spear.polygon = PackedVector2Array([Vector2(-8,32),Vector2(-8,-10),Vector2(0,-32),Vector2(8,-10),Vector2(8,32)])
	spear.color = Color("#ff6786")
	root.add_child(spear); spear.owner = root
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new(); shape.size = Vector2(16,64)
	collision.shape = shape
	root.add_child(collision); collision.owner = root
	var animator := AnimationPlayer.new(); animator.name = "AnimationPlayer"
	root.add_child(animator); animator.owner = root
	var animation := Animation.new(); animation.length = 2.5; animation.loop_mode = Animation.LOOP_LINEAR
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("Spear:position:y"))
	animation.track_insert_key(track, 0.0, 58.0); animation.track_insert_key(track, 1.0, 58.0); animation.track_insert_key(track, 1.25, 0.0); animation.track_insert_key(track, 2.1, 0.0); animation.track_insert_key(track, 2.5, 58.0)
	var library := AnimationLibrary.new(); library.add_animation("push", animation); animator.add_animation_library("", library)
	var packed := PackedScene.new(); packed.pack(root); ResourceSaver.save(packed,"res://scenes/trap_spear.tscn"); root.free()

func _make_simple_trap(node_name: String, path: String, color: Color, pendulum: bool, group_name: String) -> void:
	var root := AnimatableBody2D.new(); root.name = node_name; root.add_to_group(group_name)
	var polygon := Polygon2D.new(); polygon.name = "Visual"; polygon.color = color
	polygon.polygon = PackedVector2Array([Vector2(-42,-12),Vector2(42,-12),Vector2(42,12),Vector2(-42,12)]) if not pendulum else PackedVector2Array([Vector2(-12,-110),Vector2(12,-110),Vector2(12,0),Vector2(-12,0)])
	root.add_child(polygon); polygon.owner = root
	var collision := CollisionShape2D.new(); collision.name="CollisionShape2D"; var shape:=RectangleShape2D.new(); shape.size=Vector2(84,24) if not pendulum else Vector2(24,110); collision.shape=shape
	root.add_child(collision); collision.owner=root
	var animator:=AnimationPlayer.new(); animator.name="AnimationPlayer"; root.add_child(animator); animator.owner=root
	var animation:=Animation.new(); animation.length=2.5; animation.loop_mode=Animation.LOOP_LINEAR
	var track:=animation.add_track(Animation.TYPE_VALUE); animation.track_set_path(track,NodePath(".:rotation" if pendulum else ".:position"))
	if pendulum:
		animation.track_insert_key(track,0.0,-0.65); animation.track_insert_key(track,1.25,0.65); animation.track_insert_key(track,2.5,-0.65)
	else:
		animation.track_insert_key(track,0.0,Vector2(-80,0)); animation.track_insert_key(track,1.25,Vector2(80,0)); animation.track_insert_key(track,2.5,Vector2(-80,0))
	var lib:=AnimationLibrary.new(); lib.add_animation("move",animation); animator.add_animation_library("",lib); animator.autoplay="move"
	var packed:=PackedScene.new(); packed.pack(root); ResourceSaver.save(packed,path); root.free()

func _make_projectile() -> void:
	var root := Area2D.new(); root.name = "EnergyBolt"; root.add_to_group("Projectiles"); root.set_script(load("res://scripts/components/projectile.gd"))
	var visual := Polygon2D.new(); visual.name = "Visual"; visual.color = Color("#7df9ff"); visual.polygon = PackedVector2Array([Vector2(-14,-5),Vector2(14,-5),Vector2(20,0),Vector2(14,5),Vector2(-14,5)]); root.add_child(visual); visual.owner=root
	var collision:=CollisionShape2D.new(); collision.name="CollisionShape2D"; var shape:=RectangleShape2D.new(); shape.size=Vector2(32,10); collision.shape=shape; root.add_child(collision); collision.owner=root
	root.body_entered.connect(Callable(root, "_on_body_entered"))
	var packed:=PackedScene.new(); packed.pack(root); ResourceSaver.save(packed,"res://scenes/energy_bolt.tscn"); root.free()

func _make_items() -> void:
	_make_item("HeartItem", "heart", Color("#ff5d78"), "res://scenes/item_heart.tscn")
	_make_item("SpeedItem", "speed", Color("#ffce66"), "res://scenes/item_speed.tscn")
	_make_item("JumpItem", "jump", Color("#b58aff"), "res://scenes/item_jump.tscn")
	_make_item("CrystalItem", "crystal", Color("#70f8ff"), "res://scenes/item_crystal.tscn")

func _make_item(node_name: String, item_type: String, color: Color, path: String) -> void:
	var root:=Area2D.new(); root.name=node_name; root.add_to_group("Items"); root.set_meta("item_type",item_type)
	var visual:=Polygon2D.new(); visual.name="Visual"; visual.color=color; visual.polygon=PackedVector2Array([Vector2(0,-22),Vector2(17,0),Vector2(0,22),Vector2(-17,0)]); root.add_child(visual); visual.owner=root
	var collision:=CollisionShape2D.new(); collision.name="CollisionShape2D"; var shape:=CircleShape2D.new(); shape.radius=22; collision.shape=shape; root.add_child(collision); collision.owner=root
	var particles:=GPUParticles2D.new(); particles.name="PickupEffect"; particles.amount=12; particles.one_shot=true; particles.emitting=false; root.add_child(particles); particles.owner=root
	var packed:=PackedScene.new(); packed.pack(root); ResourceSaver.save(packed,path); root.free()

func _make_ui_scenes() -> void:
	_make_ui("MainMenu", "SKYFORGE RUNNER\nเริ่มเกม  •  เครดิต  •  ออกจากเกม", "res://scenes/menu.tscn")
	_make_ui("Credits", "เครดิต\nนายปัณณวัชร์ เชเดช\n673380079-5\nComputer Game Development", "res://scenes/credit.tscn")
	_make_ui("GameOver", "GAME OVER\nกด R เพื่อลองใหม่", "res://scenes/game_over.tscn")
	_make_ui("WinGame", "MISSION COMPLETE\nภารกิจ Skyforge สำเร็จ", "res://scenes/win_game.tscn")

func _make_ui(node_name: String, text: String, path: String) -> void:
	var root:=Control.new(); root.name=node_name; root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel:=ColorRect.new(); panel.name="Backdrop"; panel.color=Color(0.02,0.04,0.12,0.92); panel.position=Vector2(300,160); panel.size=Vector2(680,400); root.add_child(panel); panel.owner=root
	var label:=Label.new(); label.name="Title"; label.text=text; label.position=Vector2(340,220); label.size=Vector2(600,260); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size",30); root.add_child(label); label.owner=root
	var packed:=PackedScene.new(); packed.pack(root); ResourceSaver.save(packed,path); root.free()
