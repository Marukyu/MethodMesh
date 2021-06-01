extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var time = 0

const radius = 4
const minRepulse = 0
const maxRepulse = 10

const springLength = 2
const springFactor = 50
const springMax = 1000
const springFactorIncoming = 1
const springFactorOutgoing = 2

const originFactor = 1

const convergenceRate = 0.005

var velocityFactor = 1

var NodeClass = preload("res://CallGraph/GraphNode.tscn")
var EdgeClass = preload("res://CallGraph/Edge.tscn")

var nodesByName = {}
var nodeVel = {}
var nodeEdgeCount = {}
var nodeList = []
var edges = []
var bidiEdges = []
var nodeDistances = {}

var cameraPosition = Vector3(0, 0, 0)


func connectNodes(node1, node2, edge):
	edge.look_at_from_position(node1.translation, node2.translation, node1.translation - cameraPosition)
	edge.translation = node1.translation
	edge.scale.z = (node1.translation.distance_to(node2.translation) / 8)


func reset():
	loadJSON("user://callgraph.json")


# Called when the node enters the scene tree for the first time.
func _ready():
	reset()


func _input(event):
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_R:
			reset()


func initVelocities():
	nodeVel = {}
	for node in nodeList:
		nodeVel[node] = Vector3(0, 0, 0)


func processOverlap(delta):
	for node1 in nodeList:
		for node2 in node1.get_overlapping_areas():
			# Skip nodes with edges
			if not node2 in nodeDistances[node1]:
				var force = (node1.translation - node2.translation)
				var factor = clamp(force.length() / radius, 0, 1)
				force = force.normalized() * ((1 - factor) * maxRepulse + factor * minRepulse) * delta
				nodeVel[node1] += force
				nodeVel[node2] -= force

func processEdgeConstraints(delta):
	for edge in bidiEdges:
		var node1 = edge[0]
		var node2 = edge[1]
		var force = (node2.translation - node1.translation)
		var forceLength = clamp((force.length() - springLength) * springFactor, -springMax, springMax)
		force = force.normalized() * forceLength * delta
		nodeVel[node1] += force / (nodeEdgeCount[node1] + 2) * springFactorOutgoing
		nodeVel[node2] -= force / (nodeEdgeCount[node2] + 2) * springFactorIncoming

func applyVelocity(delta):
	var meanSquareError = 0
	for node in nodeList:
		meanSquareError += nodeVel[node].length_squared()

	velocityFactor = velocityFactor * clamp(meanSquareError / nodeList.size() * convergenceRate + (1 - convergenceRate), 0, 1)

	for node in nodeList:
		node.translation += (nodeVel[node] - node.translation * delta * originFactor) * velocityFactor

func connectAllNodes():
	for edge in edges:
		connectNodes(edge[1], edge[2], edge[0])


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	cameraPosition = get_viewport().get_camera().translation
	# Force fixed framerate
	delta = 1 / 60.0
	if velocityFactor > 0.0001:
		initVelocities()
		processOverlap(delta)
		processEdgeConstraints(delta)
		applyVelocity(delta)
	connectAllNodes()


func loadJSON(filename):
	var file = File.new()
	file.open(filename, File.READ)
	var json = JSON.parse(file.get_as_text()).result

	for n in $Nodes.get_children():
		$Nodes.remove_child(n)
		n.queue_free()

	for e in $Edges.get_children():
		$Edges.remove_child(e)
		e.queue_free()

	nodesByName = {}
	nodeEdgeCount = {}
	nodeList = []
	edges = []
	bidiEdges = []
	nodeDistances = {}

	velocityFactor = 1

	for node in json.nodes:
		# Skip "null function" node, because it doesn't actually call these functions
		if node.name != "null function":
			var nodeObject = NodeClass.instance()
			nodeObject.translation = Vector3(rand_range(-5, 5), rand_range(-5, 5), rand_range(-5, 5))
			$Nodes.add_child(nodeObject)
			nodesByName[node.name] = nodeObject
			nodeList.append(nodeObject)
			nodeEdgeCount[nodeObject] = 0
			nodeDistances[nodeObject] = {}

	for node in json.nodes:
		for edge in node.edges:
			if edge != node.name and node.name in nodesByName and edge in nodesByName:
				var edgeObject = EdgeClass.instance()
				$Edges.add_child(edgeObject)
				var node1 = nodesByName[node.name]
				var node2 = nodesByName[edge]
				edges.append([edgeObject, node1, node2])
				if node.name < edge:
					bidiEdges.append([node1, node2])
				else:
					bidiEdges.append([node2, node1])
				nodeEdgeCount[node1] += 1
				nodeEdgeCount[node2] += 1
				# TODO remove duplicate edges
				nodeDistances[node1][node2] = 1
				nodeDistances[node2][node1] = 1
