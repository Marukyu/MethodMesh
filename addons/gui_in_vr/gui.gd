extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

signal datasetLoaded(path)


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_LoadButton_pressed():
	emit_signal("datasetLoaded", $Panel/DatasetContainer/TextEdit.text)


func _on_FileBrowserButton_pressed():
	$FileDialog.show()


func _on_FileDialog_file_selected(path):
	$Panel/DatasetContainer/TextEdit.text = path
