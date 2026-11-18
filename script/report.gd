extends Button

@export var url: String

func _on_pressed() -> void:
	OS.shell_open(url)
