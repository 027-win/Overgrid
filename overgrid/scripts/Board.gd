extends Node2D

const TILE_SCENE = preload("res://scenes/Tile.tscn")
const COLS = 6
const ROWS = 8
const TILE_SIZE = 156
const GAP = 10
const TILE_STEP = TILE_SIZE + GAP
const BASE_WIDTH = 1080.0
const BASE_HEIGHT = 1920.0
const TOP_UI_HEIGHT = 180.0
const BOTTOM_UI_HEIGHT = 120.0
const MIN_CHAIN_LENGTH = 3

# Reduced special tile spawn rate (less boring)
const BOMB_CHANCE = 0.035
const COLOR_BOMB_CHANCE = 0.025
const MULTIPLIER_CHANCE = 0.035

var tiles: Array = []
var chain: Array = []
var is_chaining: bool = false
var chain_color: int = -1
var is_animating: bool = false
var grid_offset: Vector2 = Vector2.ZERO

@onready var tile_container: Node2D = $TileContainer
@onready var chain_line: Line2D = $ChainLine
@onready var chain_counter: Label = $ChainCounter

func _ready() -> void:
	await get_tree().process_frame
	spawn_board()

func spawn_board() -> void:
	var board_pixel_width = COLS * TILE_STEP - GAP
	var board_pixel_height = ROWS * TILE_STEP - GAP
	var available_height = BASE_HEIGHT - TOP_UI_HEIGHT - BOTTOM_UI_HEIGHT
	grid_offset = Vector2(
		(BASE_WIDTH - board_pixel_width) / 2.0,
		TOP_UI_HEIGHT + (available_height - board_pixel_height) / 2.0
	)
	tiles.resize(COLS)
	for col in range(COLS):
		tiles[col] = []
		for row in range(ROWS):
			var tile = _create_tile(col, row)
			tile.position = grid_offset + Vector2(col * TILE_STEP, row * TILE_STEP)
			tiles[col].append(tile)

func _create_tile(col: int, row: int) -> Tile:
	var tile = TILE_SCENE.instantiate()
	tile.grid_pos = Vector2i(col, row)
	tile_container.add_child(tile)
	
	var luck = GameManager.upgrade_levels.get("lucky_draw", 0) * 0.04
	var bomb_chance = BOMB_CHANCE + luck
	var cbomb_chance = COLOR_BOMB_CHANCE + luck
	var multi_chance = MULTIPLIER_CHANCE + luck
	
	var colors = GameManager.active_colors
	var roll = randf()
	if roll < bomb_chance:
		tile.set_as_bomb()
	elif roll < bomb_chance + cbomb_chance:
		tile.set_as_color_bomb()
	elif roll < bomb_chance + cbomb_chance + multi_chance:
		tile.set_as_multiplier(randi() % colors)
	else:
		tile.set_color(randi() % colors)
	return tile

func get_tile(col: int, row: int):
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return null
	return tiles[col][row]

func get_tile_world_pos(col: int, row: int) -> Vector2:
	return grid_offset + Vector2(col * TILE_STEP, row * TILE_STEP)

func _input(event: InputEvent) -> void:
	if is_animating: return
	if event is InputEventScreenTouch:
		if event.pressed: _on_press(event.position)
		else: _on_release()
	elif event is InputEventScreenDrag and is_chaining:
		_on_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _on_press(event.position)
		else: _on_release()
	elif event is InputEventMouseMotion and is_chaining:
		_on_drag(event.position)

func _on_press(screen_pos: Vector2) -> void:
	var tile = get_tile_at_screen_pos(screen_pos)
	if tile == null or tile.is_bomb() or tile.is_color_bomb(): return
	chain = [tile]
	chain_color = tile.color_id
	is_chaining = true
	tile.set_selected(true)
	update_chain_line()
	_update_chain_counter()

func _on_drag(screen_pos: Vector2) -> void:
	var tile = get_tile_at_screen_pos(screen_pos)
	if tile == null: return
	if chain.size() >= 2 and tile == chain[chain.size() - 2]:
		chain[-1].set_selected(false)
		chain.pop_back()
		update_chain_line()
		_update_chain_counter()
		return
	if chain.has(tile): return
	var can_join = tile.is_bomb() or tile.is_color_bomb() or tile.color_id == chain_color
	if not can_join or not is_adjacent(tile, chain[-1]): return
	chain.append(tile)
	tile.set_selected(true)
	update_chain_line()
	_update_chain_counter()

func _on_release() -> void:
	if not is_chaining: return
	is_chaining = false
	if chain.size() >= MIN_CHAIN_LENGTH:
		resolve_chain()
	else:
		cancel_chain()

func cancel_chain() -> void:
	for tile in chain: tile.set_selected(false)
	chain.clear()
	chain_color = -1
	update_chain_line()
	_hide_chain_counter()

func resolve_chain() -> void:
	is_animating = true
	var destroy_list = chain.duplicate()
	var energy_multiplier = 1.0

	var i = 0
	while i < destroy_list.size():
		var tile = destroy_list[i]
		match tile.tile_type:
			Tile.TileType.BOMB:
				for neighbor in _get_explosion_tiles(tile):
					if not destroy_list.has(neighbor):
						destroy_list.append(neighbor)
			Tile.TileType.COLOR_BOMB:
				for col in range(COLS):
					for row in range(ROWS):
						var t = tiles[col][row]
						if t != null and t.color_id == chain_color and not destroy_list.has(t):
							destroy_list.append(t)
			Tile.TileType.MULTIPLIER:
				energy_multiplier *= 2.0
		i += 1

	var cascades = _get_all_cascades(destroy_list)
	destroy_list += cascades
	var cascade_bonus = 1.0 + (cascades.size() * 0.22)

	if chain.size() >= 6 and GameManager.upgrade_levels.get("long_chain", 0) > 0:
		energy_multiplier *= 2.0

	var destroyed = destroy_list.size()
	var energy_gained = destroyed * destroyed * 1.28 * energy_multiplier * cascade_bonus
	GameManager.add_energy(energy_gained)

	if destroyed >= 18:
		GameManager.trigger_surge(GameManager.SURGE_MEGA_MULT, GameManager.SURGE_MEGA_DUR)
		GameManager.add_grid_tokens(5 + (destroyed / 8))
	elif destroyed >= 12:
		GameManager.trigger_surge(GameManager.SURGE_BIG_MULT, GameManager.SURGE_BIG_DUR)
		GameManager.add_grid_tokens(3)
	elif destroyed >= 7:
		GameManager.trigger_surge(GameManager.SURGE_SMALL_MULT, GameManager.SURGE_SMALL_DUR)

	var chain_center = _get_chain_center()
	var resolved_color = chain_color
	chain.clear()
	chain_color = -1
	update_chain_line()
	_hide_chain_counter()

	for tile in destroy_list:
		tiles[tile.grid_pos.x][tile.grid_pos.y] = null

	_spawn_combo_label(chain_center, destroyed, energy_multiplier, resolved_color)

	await animate_destroy(destroy_list)
	for tile in destroy_list:
		tile.queue_free()
	await apply_gravity_and_refill()
	is_animating = false

func _get_all_cascades(initial_list: Array) -> Array:
	var extra = []
	var to_process = initial_list.duplicate()
	var processed = {}
	for t in initial_list:
		processed[t] = true
	
	while not to_process.is_empty():
		var current = to_process.pop_back()
		if not (current.is_bomb() or current.is_color_bomb()): continue
		for neighbor in _get_explosion_tiles(current):
			if not processed.has(neighbor):
				processed[neighbor] = true
				extra.append(neighbor)
				to_process.append(neighbor)
	return extra

func animate_destroy(destroy_list: Array) -> void:
	for tile in destroy_list:
		if tile.is_bomb() or tile.is_color_bomb():
			tile.scale = Vector2(1.4, 1.4)
	var tween = create_tween()
	tween.set_parallel(true)
	for tile in destroy_list:
		tween.tween_property(tile, "scale", Vector2.ZERO, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	await tween.finished

func apply_gravity_and_refill() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	for col in range(COLS):
		var survivors = []
		for row in range(ROWS - 1, -1, -1):
			if tiles[col][row] != null:
				survivors.append(tiles[col][row])
		for row in range(ROWS):
			tiles[col][row] = null
		for i in range(survivors.size()):
			var target_row = ROWS - 1 - i
			var tile = survivors[i]
			tiles[col][target_row] = tile
			tile.grid_pos = Vector2i(col, target_row)
			var target_pos = get_tile_world_pos(col, target_row)
			if tile.position != target_pos:
				tween.tween_property(tile, "position", target_pos, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		var empty_count = ROWS - survivors.size()
		for i in range(empty_count):
			var target_row = empty_count - 1 - i
			var new_tile = _create_tile(col, target_row)
			var target_pos = get_tile_world_pos(col, target_row)
			new_tile.position = Vector2(target_pos.x, grid_offset.y - (i + 1) * TILE_STEP)
			tiles[col][target_row] = new_tile
			tween.tween_property(new_tile, "position", target_pos, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	await tween.finished

func _get_explosion_tiles(bomb: Tile) -> Array:
	var result = []
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			var neighbor = get_tile(bomb.grid_pos.x + dc, bomb.grid_pos.y + dr)
			if neighbor != null:
				result.append(neighbor)
	return result

func is_adjacent(a: Tile, b: Tile) -> bool:
	return abs(a.grid_pos.x - b.grid_pos.x) <= 1 and abs(a.grid_pos.y - b.grid_pos.y) <= 1 and a != b

func get_tile_at_screen_pos(screen_pos: Vector2) -> Tile:
	var world_pos = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	for col in range(COLS):
		for row in range(ROWS):
			var tile = tiles[col][row]
			if tile == null: continue
			if Rect2(tile.position, Vector2(TILE_SIZE, TILE_SIZE)).has_point(world_pos):
				return tile
	return null

func _get_chain_center() -> Vector2:
	var center = Vector2.ZERO
	for tile in chain:
		center += tile.position + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	return center / chain.size()

func _spawn_combo_label(world_pos: Vector2, count: int, multiplier: float, color_id: int) -> void:
	var label = Label.new()
	var display_color = Tile.COLORS[color_id] if color_id >= 0 else Color("#FF44FF")
	label.text = ("+%d x%.0f" % [count, multiplier]) if multiplier > 1.0 else ("+%d" % count)
	label.add_theme_font_size_override("font_size", 88)
	label.add_theme_color_override("font_color", display_color)
	label.z_index = 10
	tile_container.add_child(label)
	label.position = world_pos - Vector2(80, 60)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 180, 0.65).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, 0.65).set_ease(Tween.EASE_IN)
	await tween.finished
	label.queue_free()

func update_chain_line() -> void:
	chain_line.clear_points()
	if chain.is_empty(): return
	var line_color = Tile.COLORS[chain_color] if chain_color >= 0 else Color("#FF44FF")
	chain_line.default_color = line_color
	chain_line.width = clamp(8.0 + chain.size() * 2.5, 8.0, 36.0)
	for tile in chain:
		chain_line.add_point(tile.position + Vector2(TILE_SIZE, TILE_SIZE) * 0.5)

func _update_chain_counter() -> void:
	if chain.is_empty():
		chain_counter.visible = false
		return
	var count = chain.size()
	chain_counter.visible = true
	var has_multiplier = false
	var has_cbomb = false
	for t in chain:
		if t.is_multiplier(): has_multiplier = true
		if t.is_color_bomb(): has_cbomb = true
	var label = str(count) + " tiles"
	if has_cbomb: label += " ALL"
	if has_multiplier: label += " x2"
	chain_counter.text = label
	var color: Color
	if count < MIN_CHAIN_LENGTH: color = Color("#888888")
	elif count < 6: color = Color("#44FF88")
	elif count < 10: color = Color("#FFDD33")
	else: color = Color("#FF4455")
	chain_counter.add_theme_color_override("font_color", color)
	var last_tile = chain[-1]
	chain_counter.position = last_tile.position + Vector2(TILE_SIZE / 2.0 - 80, -90)

func _hide_chain_counter() -> void:
	chain_counter.visible = false
