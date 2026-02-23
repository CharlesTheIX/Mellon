#!/bin/bash

set -eo pipefail

# Function definitions -------------------------------------------------------------------------------------------------------------------------------
function build() {
    local type=${1:-default}
    echo "Building application with type: $type..."
    case "$type" in
        default) 
            zig build
            echo "Build complete."
            ;;

        *) 
            echo "Error: Unknown build type '$type'. Supported types are: 'default'."
            return 1
            ;;
    esac
}

function clean() {
    echo "Cleaning project..."
    rm -rf .zig-cache zig-out
    echo "Clean complete"
}

function dev() {
    zig build run
}

function help() {
    echo "Available commands:"
    echo "  help           Show this help message"
    echo "  clean          Remove build artifacts and cache"
    echo "  dev            Build and run the application in development mode"
    echo "  run [args...]  Run the built application with optional arguments"
    echo "  build [type]   Build the application (default type is 'default')"
}

function run() {
    ~/repos/mellon/zig-out/bin/mellon "$@"
}

# Main entry point -----------------------------------------------------------------------------------------------------------------------------------
if [ $# -lt 1 ]; then
    help
fi

COMMAND=$1
shift

case "$COMMAND" in
    help) help ;;
    clean) clean ;;
    dev) dev "$@" ;;
    run) run "$@" ;;
    build) build "$@" ;;
    *) echo "Unknown command: $COMMAND"; echo ""; help ;;
esac