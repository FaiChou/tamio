#!/bin/bash

set -e

cd "$(dirname "$0")"
cd ../../

# The repository root holds the workspace.
if [ ! -d App.xcworkspace ]; then
    echo "malformed project structure, missing App.xcworkspace"
    exit 1
fi

WORKING_ROOT=$(pwd)

cd "$WORKING_ROOT/Application"
swiftformat . --swiftversion 6

cd "$WORKING_ROOT/Foundation"
swiftformat . --swiftversion 6

cd "$WORKING_ROOT"

echo "done fmt"