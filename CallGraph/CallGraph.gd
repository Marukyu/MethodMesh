extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var time = 0


func connectNodes(node1, node2, edge):
	edge.look_at_from_position(node1.translation, node2.translation, Vector3.UP)
	edge.translation = node1.translation
	edge.scale.z = (node1.translation.distance_to(node2.translation) / 8)


# Called when the node enters the scene tree for the first time.
func _ready():
	connectNodes($TestNode, $TestNode2, $Edge)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	time += delta
	$TestNode.translation.x = sin(time) * 5
	connectNodes($TestNode, $TestNode2, $Edge)
	pass


func _physics_process(_delta):
	pass
