extends RefCounted

class Occupant:
	var id: int
	var instance: Node2D
	var rect: Rect2i

# ---------------- const ----------------
const INVALID_ID := -1

# ---------------- data ----------------
var _cell_to_id: Dictionary[Vector2i, int] = {}    # Vector2i -> id
var _id_to_occupant: Dictionary[int, Occupant] = {}     # id -> Occupant
var _id_seq: int = 1

# ---------------- check funcs ----------------
func is_cell_free(cell: Vector2i) -> bool: return not _cell_to_id.has(cell)

func any_occupied(rect: Rect2i) -> bool:
	for y in rect.size.y:
		var gy := rect.position.y + y
		for x in rect.size.x:
			var gx = rect.position.x + x
			var cell := Vector2i(gx, gy)
			if _cell_to_id.has(cell):
						return true
	return false

# ---------------- get funcs ----------------
func get_id_at(cell: Vector2i) -> int: return _cell_to_id.get(cell, INVALID_ID)

func get_occupant(id: int) -> Occupant: return _id_to_occupant.get(id, null)

func get_neighbors(cell: Vector2i) -> Array[int]:
	var ids: Array[int] = []
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var id :int= _cell_to_id.get(cell + d, INVALID_ID)
		if id != INVALID_ID and not ids.has(id):
			ids.append(id)
	return ids

# ---------------- operation funcs ----------------
func add(instance: Node2D, rect:Rect2i) -> Occupant:
	var occupant := Occupant.new()
	occupant.id = _id_seq
	occupant.instance = instance
	_id_to_occupant.set(occupant.id, occupant)
	# todo fix	
	if !any_occupied(rect): 
		occupant.rect = rect
		for y in rect.size.y:
			var gy := rect.position.y + y
			for x in rect.size.x:
				var gx = rect.position.x + x
				var cell := Vector2i(gx, gy)
				_cell_to_id.set(cell, occupant.id)

	_id_seq += 1
	return occupant

func remove_at_cell(cell: Vector2i) -> void:
	if not _cell_to_id.has(cell):
		return
	var id := _cell_to_id[cell]
	destroy_by_id(id)

func detach_by_id(id: int) -> Occupant:
	if not _id_to_occupant.has(id):
		return null
	var occupant: Occupant = _id_to_occupant[id]
	
	var rect:= occupant.rect
	for y in rect.size.y:
		var gy := rect.position.y + y
		for x in rect.size.x:
			var gx = rect.position.x + x
			var cell := Vector2i(gx, gy)
			_cell_to_id.erase(cell)

	return occupant

func attach(id: int, rect: Rect2i) -> void:
	if not _id_to_occupant.has(id):
		return
	var occupant :Occupant = _id_to_occupant.get(id)
	occupant.rect = rect
	for y in rect.size.y:
		var gy := rect.position.y + y
		for x in rect.size.x:
			var gx = rect.position.x + x
			var cell := Vector2i(gx, gy)
			_cell_to_id.set(cell, id)

func destroy_by_id(id: int) -> void:
	if not _id_to_occupant.has(id):
		return
	var occupant: Occupant = _id_to_occupant[id]
	var rect := occupant.rect
	for y in rect.size.y:
		var gy := rect.position.y + y
		for x in rect.size.x:
			var gx = rect.position.x + x
			var cell := Vector2i(gx, gy)
			_cell_to_id.erase(cell)
		
	if is_instance_valid(occupant.instance):
		occupant.instance.queue_free()
	_id_to_occupant.erase(id)
