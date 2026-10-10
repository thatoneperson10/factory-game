
extends Node2D

const TILE_SIZE = 32
const GRID_WIDTH = 20
const GRID_HEIGHT = 15
const MOVE_INTERVAL = 0.4

var belts: Dictionary = {}
var direction := Vector2i.RIGHT

# Stores the grid positions of iron ore
var items: Array[Vector2i] = []

var move_timer: float = 0.0


func _ready() -> void:
	$Camera2D.position = Vector2(320, 240)
	queue_redraw()


func _process(delta: float) -> void:
	move_timer += delta

	if move_timer >= MOVE_INTERVAL:
		move_timer -= MOVE_INTERVAL
		move_items()


func _draw() -> void:
	# Draw the factory grid
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos = Vector2(x, y) * TILE_SIZE
			var rect = Rect2(
				pos,
				Vector2(TILE_SIZE, TILE_SIZE)
			)

			draw_rect(rect, Color("#293d36"))
			draw_rect(rect, Color("#476052"), false, 1.0)

	# Draw conveyor belts
	for cell in belts:
		var pos = Vector2(cell) * TILE_SIZE
		var center = pos + Vector2(16, 16)

		draw_rect(
			Rect2(
				pos + Vector2(2, 2),
				Vector2(28, 28)
			),
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

	# Draw iron ore items
	for cell in items:
		var pos = Vector2(cell) * TILE_SIZE

		draw_circle(
			pos + Vector2(16, 16),
			7,
			Color("#b0bec5")
		)


func _unhandled_input(event: InputEvent) -> void:
	# Keyboard controls
	if event is InputEventKey:
		if event.pressed and not event.echo:

			# Rotate conveyor direction
			if event.keycode == KEY_R:
				direction = Vector2i(
					-direction.y,
					direction.x
				)

			# Spawn iron ore on a conveyor
			if event.keycode == KEY_SPACE:
				var mouse = get_global_mouse_position()

				var cell = Vector2i(
					floori(mouse.x / TILE_SIZE),
					floori(mouse.y / TILE_SIZE)
				)

				if is_inside_grid(cell) and belts.has(cell):
					if not items.has(cell):
						items.append(cell)
						queue_redraw()

	# Mouse controls
	if event is InputEventMouseButton and event.pressed:
		var mouse = get_global_mouse_position()

		var cell = Vector2i(
			floori(mouse.x / TILE_SIZE),
			floori(mouse.y / TILE_SIZE)
		)

		if not is_inside_grid(cell):
			return

		# Place conveyor
		if event.button_index == MOUSE_BUTTON_LEFT:
			belts[cell] = direction
			queue_redraw()

		# Remove conveyor and any item on it
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			belts.erase(cell)
			items.erase(cell)
			queue_redraw()


func move_items() -> void:
	# Track where items are currently located
	var occupied: Dictionary = {}

	for item in items:
		occupied[item] = true

	# Build proposed movements
	var new_items: Array[Vector2i] = []
	var reserved: Dictionary = {}

	for item in items:
		var next_cell = item

		if belts.has(item):
			var target: Vector2i = item + belts[item]

			# Items only move onto another conveyor
			if (
				is_inside_grid(target)
				and belts.has(target)
				and not occupied.has(target)
				and not reserved.has(target)
			):
				next_cell = target

		new_items.append(next_cell)
		reserved[next_cell] = true

	items = new_items
	queue_redraw()


func is_inside_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < GRID_WIDTH
		and cell.y >= 0
		and cell.y < GRID_HEIGHT
	)
