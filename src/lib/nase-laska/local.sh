#!/bin/bash

set -eo pipefail

function write_mac_app_info_plist() {
cat > NaseLaska.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>naselaska</string>
    <key>CFBundleIdentifier</key>
    <string>com.nase.laska</string>
    <key>CFBundleName</key>
    <string>NaseLaska</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
}

# Function definitions -------------------------------------------------------------------------------------------------------------------------------

function optimize() {
    local optimize_flag=${1:-}
    local windows=${2:-}

    if [ -n "$windows" ]; then
        case "$optimize_flag" in
            -safe) zig build -Doptimize=ReleaseSafe -Dtarget=x86_64-windows ;;
            -fast) zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows ;;
            -small) zig build -Doptimize=ReleaseSmall -Dtarget=x86_64-windows ;;
            *) zig build -Dtarget=x86_64-windows ;;
        esac
        return
    fi

    case "$optimize_flag" in
        -safe) zig build -Doptimize=ReleaseSafe ;;
        -fast) zig build -Doptimize=ReleaseFast ;;
        -small) zig build -Doptimize=ReleaseSmall ;;
        *) zig build ;;
    esac
}
function build() {
    local type=${1:-}
    local optimize_flag=${2:-}

    echo "Building application with type: $type..."
    case "$type" in
        macos)
            optimize "$optimize_flag"
            echo "Creating NaseLaska.app bundle..."
            rm -rf NaseLaska.app
            mkdir -p NaseLaska.app/Contents/MacOS
            mkdir -p NaseLaska.app/Contents/Resources
            cp zig-out/bin/naselaska NaseLaska.app/Contents/MacOS/
            write_mac_app_info_plist
            echo "macOS app bundle created in zig-out/app/NaseLaska.app"
            ;;

        windows)
            optimize "$optimize_flag" -windows
            echo "Creating Windows distribution package..."
            rm -rf NaseLaska
            mkdir -p NaseLaska
            if [ -f zig-out/bin/naselaska.exe ]; then
                cp zig-out/bin/naselaska.exe NaseLaska/NaseLaska.exe
                echo "✅ NaseLaska/NaseLaska.exe created successfully!"
                echo "Package contents:"
                ls -lh NaseLaska/
            else
                echo "Error: naselaska.exe not found. Build for Windows target first:"
                echo "  zig build -Dtarget=x86_64-windows"
                return 1
            fi
            ;;
        *)
            optimize "$optimize_flag"
            ;;
    esac

    echo "Bundle size: $(get_bundle_size $type)"
}

function get_bundle_size() {
    local type=${1:-default}
    case "$type" in
        macos)
            if [ -d "NaseLaska.app" ]; then
                du -sh NaseLaska.app | awk '{print $1}'
            else
                echo "NaseLaska.app not found."
            fi
            ;;
        windows)
            if [ -f "NaseLaska/NaseLaska.exe" ]; then
                du -h NaseLaska/NaseLaska.exe | awk '{print $1}'
            else
                echo "NaseLaska.exe not found."
            fi
            ;;
        *)
            if [ -f "zig-out/bin/naselaska" ]; then
                du -h zig-out/bin/naselaska | awk '{print $1}'
            else
                echo "naselaska binary not found."
            fi
            ;;
    esac
    
}

function clean() {
    echo "Cleaning build artifacts..."
    rm -rf .zig-cache zig-out NaseLaska.app NaseLaska
    echo "Clean complete."
}

function help() {
    echo "Available commands:"
    echo "  build [type] [optimize]   Build the application."
    echo "    Types: macos, windows (default: standard build)"
    echo "    Optimize: -safe, -fast, -small (default: none)"
    echo "    Examples:"
    echo "      ./local.sh build                  # Standard build"
    echo "      ./local.sh build macos            # Create macOS app bundle"
    echo "      ./local.sh build macos -fast      # Create macOS app with fast optimizations"
    echo "      ./local.sh build windows -small   # Create Windows exe with size optimization"
    echo "  run            Run the application"
    echo "  clean          Clean build artifacts"
    echo "  help           Show this help message"
}

function run() {
    local os=$(uname -s)
    case "$os" in
        Darwin)
            echo "Running NaseLaska on macOS..."
            ./zig-out/bin/naselaska
            ;;
        Linux)
            echo "Running NaseLaska on Linux..."
            ./zig-out/bin/naselaska
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "Running NaseLaska on Windows..."
            ./zig-out/bin/naselaska.exe
            ;;
        *)
            echo "Unsupported OS: $os"
            exit 1
            ;;
    esac
}

# Main entry point -----------------------------------------------------------------------------------------------------------------------------------
if [ $# -lt 1 ]; then
    help
fi

COMMAND=$1
shift

start_time=$(date +%s)

case "$COMMAND" in
    help) help ;;
    run) run ;;
    clean) clean ;;
    build) build "$@" ;;
    *) echo "Unknown command: $COMMAND"; echo ""; help; process_exit 1 ;;
esac

end_time=$(date +%s)
elapsed=$((end_time - start_time))
echo "Command '$COMMAND' completed in $elapsed seconds."