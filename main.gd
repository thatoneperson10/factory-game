
extends Node2D

const TILE_SIZE = 32
const GRID_WIDTH = 20
const GRID_HEIGHT = 15
const MOVE_INTERVAL = 0.4

var belts: Dictionary = {}
var miners: Dictionary = {}
var furnaces: Dictionary = {}
var depots: Dictionary = {}

var items: Array[Dictionary] = []

var direction := Vector2i.RIGHT
var build_mode := "belt"
var move_timer := 0.0
var tick_count := 0

var iron_plates := 0


func _ready() -> void:
	$Camera2D.position = Vector2(320, 240)
	print("Rustbelt Industries started!")
	print("B: Belt | M: Miner | F: Furnace | T: Storage")
	print("R: Rotate belt | Space: Spawn ore")
	queue_redraw()


func _process(delta: float) -> void:
	move_timer += delta

	while move_timer >= MOVE_INTERVAL:
		move_timer -= MOVE_INTERVAL
		simulation_tick()


func simulation_tick() -> void:
	tick_count += 1

	move_items()
	update_furnaces()
	update_miners()

	queue_redraw()


func update_miners() -> void:
	# Generate one ore every 2 seconds
	if tick_count % 5 != 0:
		return

	for cell in miners:
		var target: Vector2i = cell + Vector2i.RIGHT

		if belts.has(target) and not is_occupied(target):
			items.append({
				"cell": target,
				"type": "iron_ore"
			})


func update_furnaces() -> void:
	for cell in furnaces:
		var furnace: Dictionary = furnaces[cell]

		if furnace["ore"] <= 0:
			continue

		furnace["progress"] += 1

		# 8 ticks = 3.2 seconds
		if furnace["progress"] >= 8:
			var target: Vector2i = cell + Vector2i.RIGHT

			if belts.has(target) and not is_occupied(target):
				items.append({
					"cell": target,
					"type": "iron_plate"
				})

				furnace["ore"] -= 1
				furnace["progress"] = 0
			else:
				furnace["progress"] = 8


func move_items() -> void:
	var occupied: Dictionary = {}
	var reserved: Dictionary = {}

	for item in items:
		occupied[item["cell"]] = true

	var new_items: Array[Dictionary] = []

	for item in items:
		var cell: Vector2i = item["cell"]
		var next_cell: Vector2i = cell

		if belts.has(cell):
			next_cell = cell + Vector2i(belts[cell])

		if not is_inside_grid(next_cell):
			new_items.append(item)
			continue

		# Deliver iron plates to storage
		if depots.has(next_cell):
			if item["type"] == "iron_plate":
				iron_plates += 1
				print("Iron plates collected: ", iron_plates)
				continue

		# Send ore into a furnace
		if furnaces.has(next_cell):
			if item["type"] == "iron_ore":
				var furnace: Dictionary = furnaces[next_cell]

				if furnace["ore"] < 1:
					furnace["ore"] += 1
					continue

		# Move along another conveyor
		if (
			belts.has(next_cell)
			and next_cell != cell
			and not occupied.has(next_cell)
			and not reserved.has(next_cell)
		):
			item["cell"] = next_cell

		reserved[item["cell"]] = true
		new_items.append(item)

	items = new_items


func is_occupied(cell: Vector2i) -> bool:
	for item in items:
		if item["cell"] == cell:
			return true

	return false


func _draw() -> void:
	# Factory floor
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos = Vector2(x, y) * TILE_SIZE
			var rect = Rect2(
				pos,
				Vector2(TILE_SIZE, TILE_SIZE)
			)

			draw_rect(rect, Color("#293d36"))
			draw_rect(rect, Color("#476052"), false, 1.0)

	# Conveyor belts
	for cell in belts:
		var pos = Vector2(cell) * TILE_SIZE
		var center = pos + Vector2(16, 16)

		draw_rect(
			Rect2(pos + Vector2(2, 2), Vector2(28, 28)),
			Color("#b48a50")
		)

		var arrow = Vector2(belts[cell])
		var side = Vector2(-arrow.y, arrow.x)

		var points = PackedVector2Array([
			center + arrow * 11,
			center - arrow * 6 + side * 7,
			center - arrow * 6 - side * 7
		])

		draw_colored_polygon(points, Color.WHITE)

	# Mining drills
	for cell in miners:
		draw_building(cell, Color("#9c754b"))
		draw_circle(
			Vector2(cell) * TILE_SIZE + Vector2(16, 16),
			9,
			Color("#dddddd")
		)

	# Furnaces
	for cell in furnaces:
		draw_building(cell, Color("#b55436"))
		draw_circle(
			Vector2(cell) * TILE_SIZE + Vector2(16, 16),
			9,
			Color("#ffad42")
		)

	# Storage depots
	for cell in depots:
		draw_building(cell, Color("#397b68"))

	# Moving items
	for item in items:
		var pos = Vector2(item["cell"]) * TILE_SIZE
		var color = Color("#b0bec5")

		if item["type"] == "iron_plate":
			color = Color("#63d4ed")

		draw_circle(
			pos + Vector2(16, 16),
			7,
			color
		)


func draw_building(cell: Vector2i, color: Color) -> void:
	var pos = Vector2(cell) * TILE_SIZE

	draw_rect(
		Rect2(pos + Vector2(2, 2), Vector2(28, 28)),
		color
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			match event.keycode:
				KEY_B:
					build_mode = "belt"
				KEY_M:
					build_mode = "miner"
				KEY_F:
					build_mode = "furnace"
				KEY_T:
					build_mode = "depot"
				KEY_R:
					direction = Vector2i(
						-direction.y,
						direction.x
					)
				KEY_SPACE:
					spawn_ore()

			print("Build mode: ", build_mode)

	if event is InputEventMouseButton and event.pressed:
		var cell = get_mouse_cell()

		if not is_inside_grid(cell):
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			place_building(cell)

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			remove_building(cell)

		queue_redraw()


func get_mouse_cell() -> Vector2i:
	var mouse = get_global_mouse_position()

	return Vector2i(
		floori(mouse.x / TILE_SIZE),
		floori(mouse.y / TILE_SIZE)
	)


func place_building(cell: Vector2i) -> void:
	# Don't overwrite existing structures
	if (
		belts.has(cell)
		or miners.has(cell)
		or furnaces.has(cell)
		or depots.has(cell)
		or is_occupied(cell)
	):
		return

	match build_mode:
		"belt":
			belts[cell] = direction

		"miner":
			miners[cell] = true

		"furnace":
			furnaces[cell] = {
				"ore": 0,
				"progress": 0
			}

		"depot":
			depots[cell] = true


func remove_building(cell: Vector2i) -> void:
	belts.erase(cell)
	miners.erase(cell)
	furnaces.erase(cell)
	depots.erase(cell)

	for i in range(items.size() - 1, -1, -1):
		if items[i]["cell"] == cell:
			items.remove_at(i)


func spawn_ore() -> void:
	var cell = get_mouse_cell()

	if belts.has(cell) and not is_occupied(cell):
		items.append({
			"cell": cell,
			"type": "iron_ore"
		})

		queue_redraw()


func is_inside_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < GRID_WIDTH
		and cell.y >= 0
		and cell.y < GRID_HEIGHT
	)
