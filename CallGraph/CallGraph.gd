extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var time = 0

var NodeClass = preload("res://CallGraph/GraphNode.tscn")
var EdgeClass = preload("res://CallGraph/Edge.tscn")

var nodesByName = {}
var edges = []


func connectNodes(node1, node2, edge):
	edge.look_at_from_position(node1.translation, node2.translation, Vector3.UP)
	edge.translation = node1.translation
	edge.scale.z = (node1.translation.distance_to(node2.translation) / 8)


# Called when the node enters the scene tree for the first time.
func _ready():
	loadJSON("user://callgraph.json")
	#connectNodes($TestNode, $TestNode2, $Edge)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	#connectNodes($TestNode, $TestNode2, $Edge)
	for edge in edges:
		connectNodes(edge[1], edge[2], edge[0])
	pass


func _physics_process(_delta):
	pass


func loadJSON(filename):
	var file = File.new()
	file.open(filename, File.READ)
	var json = JSON.parse(file.get_as_text()).result

	nodesByName = {}
	edges = []

	for node in json.nodes:
		var nodeObject = NodeClass.instance()
		nodeObject.translation = Vector3(rand_range(-5, 5), rand_range(-5, 5), rand_range(-5, 5))
		$Nodes.add_child(nodeObject)
		nodesByName[node.name] = nodeObject

	for node in json.nodes:
		for edge in node.edges:
			var edgeObject = EdgeClass.instance()
			$Edges.add_child(edgeObject)
			if edge in nodesByName:
				edges.append([edgeObject, nodesByName[node.name], nodesByName[edge]])
