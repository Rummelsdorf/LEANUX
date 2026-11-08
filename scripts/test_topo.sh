#!/usr/bin/env bash

# Test topological sort in isolation
declare -A graph
graph[test_a]=""
graph[test_b]="test_a"

declare -a sorted
declare -n result_arr=sorted

topological_sort graph sorted 2>/dev/null || true

echo "sorted=${sorted[@]}"
echo "count=${#sorted[@]}"
