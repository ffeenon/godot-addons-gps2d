extends RefCounted

class Occupant:
	var instance: Node2D
	var rect: Rect2i
	func _init(_instance: Node2D, _rect: Rect2i) -> void:
		instance = _instance
		rect = _rect

# ---------------- data ----------------
var _cell_to_occupant: Dictionary[Vector2i, Occupant] = {}    # Vector2i -> Occupant

# ---------------- check funcs ----------------
func is_cell_free(cell: Vector2i) -> bool: return not _cell_to_occupant.has(cell)

func any_occupied(rect: Rect2i) -> bool:
	for y in rect.size.y:
		var gy := rect.position.y + y
		for x in rect.size.x:
			var gx = rect.position.x + x
			var cell := Vector2i(gx, gy)
			if _cell_to_occupant.has(cell):
						return true
	return false

# ---------------- get funcs ----------------
func has_occupant(occupant: Occupant) -> bool: return get_occupant(occupant.rect.position) == occupant

func get_occupant(cell: Vector2i) -> Occupant: return _cell_to_occupant.get(cell, null)

func get_neighbors(cell: Vector2i) -> Array[Occupant]:
	var occupants: Array[Occupant] = []
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var occupant :Occupant = get_occupant(cell + d)
		if occupant != null and not occupants.has(occupant):
			occupants.append(occupant)
	return occupants

# ---------------- operation funcs ----------------
func detach(occupant: Occupant) -> void:	
	var rect:= occupant.rect
	for y in rect.size.y:
		var gy := rect.position.y + y
		for x in rect.size.x:
			var gx = rect.position.x + x
			var cell := Vector2i(gx, gy)
			_cell_to_occupant.erase(cell)

func attach(occupant: Occupant) -> void:
	var rect := occupant.rect
	for y in rect.size.y:
		var gy := rect.position.y + y
		for x in rect.size.x:
			var gx = rect.position.x + x
			var cell := Vector2i(gx, gy)
			_cell_to_occupant.set(cell, occupant)
