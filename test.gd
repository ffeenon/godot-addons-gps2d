extends Node2D

@export var d:Gps2dPlaceableData
func _ready() -> void:
	$GPS2D.add(d)


func _on_button_pressed() -> void:
	$GPS2D.add(d)


func _on_button_2_pressed() -> void:
	$GPS2D.add(d, false)
