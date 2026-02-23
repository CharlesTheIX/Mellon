# Naše Láska (NaseLaska)

A 2D interactive application built with **Zig** and **Raylib**, featuring map rendering, camera controls, and input handling.

## Features

- **2D Map Rendering** - Load and display tiled maps with background textures
- **Camera System** - Smooth camera movement and controls
- **Input Handling** - Keyboard input detection and tracking
- **Cross-platform Support** - Build and run on macOS and Windows
- **Development Tools** - Built-in development utilities for debugging

## Requirements

- **Zig** - Version 0.15.2 or later ([Download](https://ziglang.org/download/))
- **macOS** or **Windows** (or Linux with minor modifications)
- **Raylib** - Automatically fetched as a dependency via `raylib-zig`

## Project Structure

```
nase-laska/
├── src/
│   ├── main.zig              # Application entry point
│   ├── root.zig              # Main NaseLaska struct and game loop
│   └── lib/
│       ├── canvas.zig        # Canvas/viewport management
│       ├── camera.zig        # Camera 2D controls
│       ├── map.zig           # Map loading and rendering
│       ├── input-handler.zig # Keyboard input management
│       ├── timer.zig         # Timing utilities
│       ├── utils.zig         # Utility functions
│       └── .dev.zig          # Development tools
├── data/
│   └── maps/                 # Map files (.z) and textures (.png)
│       ├── map_test.z
│       ├── map_test.png
│       └── [more map files]
├── build.zig                 # Build configuration
├── build.zig.zon            # Dependency manifest
├── local.sh                  # Build and run helper script
└── README.md                 # This file
```

## Quick Start

### Using the Local Script (Recommended)

The project includes a `local.sh` script that handles building for different platforms:

```bash
# Make the script executable
chmod +x local.sh

# Show available commands
./local.sh help

# Build for current platform
./local.sh build default

# Build macOS app bundle (creates NaseLaska.app)
./local.sh build macos

# Build Windows executable
./local.sh build windows

# Run the application
./local.sh run

# Clean build artifacts
./local.sh clean
```

### Direct Build Commands

You can also use Zig commands directly:

```bash
# Standard build
zig build

# Cross-compile for Windows (from macOS/Linux)
zig build -Dtarget=x86_64-windows

# Run the application
zig build run
```

## Building for Distribution

### macOS App Bundle

Creates a `.app` bundle ready for macOS:

```bash
./local.sh build macos
```

Output: `NaseLaska.app/` - Ready to run or distribute

### Windows Executable

Creates a Windows executable:

```bash
./local.sh build windows
```

Output: `NaseLaska/NaseLaska.exe` - Ready to run on Windows

## Architecture

The application follows a modular architecture with the main `NaseLaska` struct:

- **Canvas** - Manages viewport dimensions
- **Camera** - Handles 2D camera positioning and updates
- **Map** - Loads map data and renders background textures
- **InputHandler** - Tracks active keyboard inputs
- **Dev** - Development/debugging utilities

The main loop runs at **60 FPS** and cycles through:

1. Update phase - Process input, camera, and map updates
2. Draw phase - Render map and UI elements

## Game Loops

### Update Cycle

- Input handler processes keyboard input
- Camera updates based on input
- Map state updates

### Draw Cycle

- Camera 2D mode enabled
- Map rendered (background texture + spawn points)
- Camera 2D mode disabled
- UI overlays drawn (input display, debug info)

## Development

### Building in Development Mode

```bash
# Debug build with optimizations disabled
zig build

# Release build with optimizations
zig build -Doptimize=ReleaseFast
```

### Extending the Project

- Add new features in `src/lib/` as separate modules
- Import and initialize in `src/root.zig`
- Add new map files to `data/maps/`
- Use the Dev system for debugging

## Dependencies

- **raylib-zig** - Zig bindings for Raylib 2D graphics library
  - Repository: https://github.com/raylib-zig/raylib-zig
  - Branch: devel

## Map Format

Maps are stored as:

- `.z` files - Binary map data (custom format)
- `.png` files - Background textures

Maps are loaded from `data/maps/` directory and referenced by ID (e.g., "test" loads `map_test.z` and `map_test.png`).

## Troubleshooting

### Build Fails on macOS

- Ensure Xcode Command Line Tools are installed: `xcode-select --install`
- Check Zig version: `zig version` should be 0.15.2+

### Build Fails on Windows

- Use the `-Dtarget=x86_64-windows` flag when cross-compiling from another OS
- Native Windows builds require proper Zig Windows support

### Executable Won't Run

- Check file permissions: `chmod +x zig-out/bin/naselaska`
- For macOS app: The app must be in the correct bundle structure created by `./local.sh build macos`

## License

[Add your license information here]

## Author

[Add author/contributor information here]
