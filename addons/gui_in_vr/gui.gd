extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

signal datasetLoaded(path)

export(NodePath) var callgraph

var colorNode = null
var colorEdge = null
var colorButton = null

func overrideButtonStyle(button: Button):
	var box = StyleBoxFlat.new()
	button.add_stylebox_override("normal", box)
	button.add_stylebox_override("hover", box)
	button.add_stylebox_override("pressed", box)
	button.add_stylebox_override("disabled", box)

func setButtonColor(button: Button, color: Color):
	button.get_stylebox("normal").bg_color = color
	var textCol = Color(0, 0, 0) if color.v > 0.5 else Color(1, 1, 1)
	button.add_color_override("font_color", textCol)
	button.add_color_override("font_color_hover", textCol)
	button.add_color_override("font_color_pressed", textCol)

# Called when the node enters the scene tree for the first time.
func _ready():
	var defaultColors = {
		Neutral = Color("f7da8e"),
		Focused = Color("e7cd99"),
		In = Color("d89c92"),
		Out = Color("6ee7d9"),
		Unrelated = Color("ffffff"),
	}
	for button in $Panel/ColorContainer.get_children():
		if button is Button:
			overrideButtonStyle(button)
			setButtonColor(button, defaultColors.get(button.name, Color("ffffff")))


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_LoadButton_pressed():
	emit_signal("datasetLoaded", $Panel/DatasetContainer/TextEdit.text)


func _on_FileBrowserButton_pressed():
	$FileDialog.show()
	$FileDialog.invalidate()


func _on_FileDialog_file_selected(path):
	$Panel/DatasetContainer/TextEdit.text = path


func _on_ColorButton_pressed(node, edge):
	$Panel/ColorPickContainer/ColorPicker.visible = true
	colorNode = node
	colorEdge = edge
	colorButton = $Panel/ColorContainer.find_node(node if node != "" else "Neutral")
	if colorButton:
		$Panel/ColorPickContainer/ColorPicker.color = colorButton.get_stylebox("normal").bg_color


func setMatAlbedo(mat: SpatialMaterial, color: Color):
	if mat:
		mat.albedo_color = Color(color.r, color.g, color.b, mat.albedo_color.a)


func _on_ColorPicker_color_changed(color):
	if colorButton:
		setButtonColor(colorButton, color)
	var cg = get_node(callgraph)
	if !cg:
		return

	var faded = cg.get("fadedMaterials")
	if typeof(colorNode) == TYPE_STRING:
		var nmat = cg.get("NodeMaterial" + colorNode)
		setMatAlbedo(nmat, color)
		setMatAlbedo(faded.get(nmat), color)
		
	if typeof(colorEdge) == TYPE_STRING:
		var cone = cg.get("EdgeConeMaterial" + colorEdge)
		var part = cg.get("EdgeParticles" + colorEdge)
		setMatAlbedo(cone, color)
		setMatAlbedo(faded.get(cone), color)
		cg.recolorParticles(part, color)
		cg.recolorParticles(faded.get(part), color)
	
