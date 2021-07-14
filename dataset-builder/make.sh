#!/bin/bash

clang++ Test.cpp -S -emit-llvm -o - \
	| opt -enable-new-pm=0 -analyze -std-link-opts -print-callgraph 2>&1 >/dev/null \
	| lua generate.lua \
	| jq . \
	> Test.json

	#| c++filt 