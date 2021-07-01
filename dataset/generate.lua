local json = require "json"

local currentNode
local nodes = {}

local nameSet = {}
local nameList = {}

local function unquote(str)
	return str:match("^'(.*)'$") or str
end

local function unverbosifyName(name)
	return name
		:gsub("std::__cxx11::basic_string", "std::basic_string")
		:gsub("std::basic_string<char,%s*std::char_traits<char>,%s*std::allocator<char>%s*>", "std::string")
		:gsub("null function", "init")
		:gsub(",%sstd::allocator%b<>%s*", "")
		:gsub(",%sstd::default_delete%b<>%s*", "")
end

local function simplifyName(name)
	return unverbosifyName(name)
end

local function processName(name)
	name = unquote(name)
	if not nameSet[name] then
		nameList[#nameList + 1] = name
		nameSet[name] = #nameList
	end
	return name
end
local edgeCount = 0

for line in io.lines() do
	local edge = currentNode and line:match("^  .* calls function (%b'')$")

	if edge then
		currentNode.edges[#currentNode.edges + 1] = processName(edge)
		edgeCount = edgeCount + 1
	else
		local nodeName = line:match("^Call graph node (.*)  #uses=%d*")
		if nodeName then
			nodeName = processName(nodeName:match("^for function: (%b'')") or nodeName:match("<<(.-)>>") or nodeName)
			if currentNode then
				nodes[#nodes + 1] = currentNode
			end
			-- Skip "null function" (doesn't actually call anything)
			if nodeName ~= "null function" then
				currentNode = {
					name = nodeName,
					edges = {},
				}
			else
				currentNode = nil
			end
		end
	end
end

if currentNode then
	nodes[#nodes + 1] = currentNode
end

local function demangle(args, func)
	local tmpname = os.tmpname()

	local pipe = io.popen("c++filt " .. (args or "") .. " > '" .. tmpname .. "'", "w")
	for _, name in ipairs(nameList) do
		pipe:write(name:gsub("\n", ""), "\n")
	end
	pipe:close()

	local demangledNames = {}
	for name in io.lines(tmpname) do
		demangledNames[#demangledNames + 1] = func and func(name) or name
	end
	return demangledNames
end

local demangledNames = demangle("--no-verbose", unverbosifyName)
local demangledSimpleNames = demangle("--no-verbose --no-params", simplifyName)

for _, node in ipairs(nodes) do
	node.displayName = demangledNames[nameSet[node.name]]
	node.simpleName = demangledSimpleNames[nameSet[node.name]]
end

io.stderr:write(tostring(#nodes), " ", tostring(edgeCount))

io.write(json.encode({nodes = nodes, initNode = (nodes[1] or {}).name}))
