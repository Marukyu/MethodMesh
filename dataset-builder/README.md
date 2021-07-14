## Requirements

- Bash
- Lua 5.1 or later
- clang
- jq
- c++filt

Only tested on Linux so far (might work under WSL2)

## Usage

`./make.sh`

This builds a dataset "Test.json" from "Test.cpp". Placing this file in `~/.local/share/godot/app_userdata/Method Mesh/callgraph.json` ensures that it is auto-loaded on startup.

