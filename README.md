# Mellon

Mellon is an interactive CLI shell written in Zig.

It provides:

- a REPL with editable input and persistent history
- built-in command groups for config, file operations, base64 utilities, benchmarking, and internal dev tests
- shell fallback for non built-in commands
- an optional Python build helper toolkit for packaging and cleanup workflows

This README documents the project as it exists in the current codebase.

## Table of Contents

- Overview
- Prerequisites
- Setup
- Build and Run with Zig
- Build and Run with Custom Python Scripts
- Mellon CLI Reference
- Command Options and Examples
- Runtime Files and Data
- Project Layout
- Notes and Current Limitations

## Overview

Core runtime flow:

1. src/main.zig initializes allocator, error handler, config, IO, and Mellon root controller.
2. src/root.zig dispatches top-level commands.
3. Command modules in src/lib and src/lib/core execute built-ins.
4. Unknown commands are passed to shell execution logic.

## Prerequisites

### Required

- Zig 0.15.2 or newer
- A POSIX-like terminal environment

### Optional but Useful

- Python 3.7+ (for custom build scripts in build/)
- iconutil (for macOS app bundle icon generation)
- code, nvim, or vim in PATH for editor-based commands

## Setup

1. Clone and enter the repository:

```bash
git clone <your-repo-url>
cd mellon
```

2. Verify Zig:

```bash
zig version
```

3. Optional Python environment for build scripts:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r build/requirements.txt
```

Note: build/requirements.txt currently has no external dependencies.

## Build and Run with Zig

### Build

```bash
zig build
```

### Run

```bash
zig build run
```

### Pass CLI args through Zig run

```bash
zig build run -- help
zig build run -- config set show_intro=false
zig build run -- fs help
```

### Output Binary

- macOS/Linux: zig-out/bin/mellon
- Windows build target: zig-out/bin/mellon.exe

## Build and Run with Custom Python Scripts

Entry point:

```bash
cd build
./main.py <command> [key=value ...]
```

You can also run:

```bash
python3 main.py <command> [key=value ...]
```

### Available Python Commands

#### 1. build

Builds Mellon, optionally with target packaging.

```bash
./main.py build
./main.py build os=macos
./main.py build os=macos optimize=fast
./main.py build os=windows optimize=small
```

Accepted key=value arguments:

- os=macos|windows
- optimize=safe|fast|small

Behavior:

- runs data preparation hook
- calls Zig build via build/utils/builders.py
- optionally creates:
- Mellon.app for macOS
- Mellon/ directory package for Windows

macOS bundle requirements:

- iconutil must be available
- icon PNG set must exist in build/assets/images:
- icon_16x16.png
- icon_16x16@2x.png
- icon_32x32.png
- icon_32x32@2x.png
- icon_128x128.png
- icon_128x128@2x.png
- icon_256x256.png
- icon_256x256@2x.png
- icon_512x512.png
- icon_512x512@2x.png

#### 2. run

Runs the built binary for the detected OS.

```bash
./main.py run
```

It expects:

- ./zig-out/bin/mellon on macOS/Linux
- ./zig-out/bin/mellon.exe on Windows

#### 3. clean

Deletes build artifacts.

```bash
./main.py clean
```

Removes:

- .data
- Mellon
- zig-out
- Mellon.app
- .zig-cache

#### 4. help

Displays Python build tool help.

```bash
./main.py help
```

Important: the help text currently mentions an audio command, but there is no audio command implementation in build/controller.py.

## Mellon CLI Reference

Top-level Mellon commands are routed in src/root.zig.

### Top-Level Commands

| Command     | Aliases | Description                                     |
| ----------- | ------- | ----------------------------------------------- |
| help        | none    | Show help text from docs/help.txt               |
| repl        | none    | Enter REPL mode                                 |
| exit        | :q      | Exit Mellon                                     |
| benchmark   | bench   | Time a Mellon command                           |
| config      | none    | Config management                               |
| file-system | fs      | File helper command group                       |
| base64      | none    | Base64 encode/decode command group              |
| \_dev       | none    | Internal development/testing command group      |
| other       | n/a     | Shell fallback (runs external commands in PATH) |

## Command Options and Examples

### help

```text
help
```

### repl

```text
repl
```

### exit

```text
exit
:q
```

### benchmark / bench

Usage:

```text
benchmark <command> [args]
bench <command> [args]
```

Examples:

```text
benchmark fs read --path=./README.md
bench base64 encode --input=hello
```

### config

Usage patterns:

```text
config
config edit
config source
config set key=value [key=value ...]
config help
config -h
```

Supported config keys in code:

- editor
- prompt
- show_intro
- show_cwd

Config file path:

- ~/.mellonrc

Generated defaults include:

- editor=vim
- prompt=⚡
- log_dir=~/.mellon_logs
- show_cwd=true
- show_intro=true

Examples:

```text
config set editor=code
config set prompt=$
config set show_intro=false show_cwd=false
config source
```

### file-system / fs

Subcommands:

- help
- read --path=FILE
- write --path=FILE [--editor=vim|nvim|code]
- copy --from=SRC --to=DEST
- delete --path=FILE
- get_abs --path=PATH

Examples:

```text
fs help
fs read --path=./README.md
fs write --path=./notes.md --editor=code
fs copy --from=./a.txt --to=./b.txt
fs delete --path=./old.md
fs get_abs --path=~/projects/mellon
```

Supported file extensions for type-checked operations:

- z
- js
- md
- ts
- txt
- json

### base64

Subcommands:

- encode
- decode
- help or -h

Option:

- --input=VALUE (if omitted, Mellon prompts for input)

Examples:

```text
base64 encode --input=hello
base64 decode --input=aGVsbG8=
base64 help
```

### \_dev

Internal development command group.

Current subcommand:

- placeholder

Examples:

```text
_dev
_dev placeholder
```

### Shell Fallback

If a command is not recognized as built-in, Mellon checks PATH and executes it.

Examples:

```text
ls -la
git status
pwd
clear
```

## REPL Behavior

Input handling in src/lib/core/io.zig currently supports:

- left and right arrow cursor movement
- up and down history navigation
- in-line editing and backspace
- Ctrl+C clears current input line
- colored output

Command history behavior in src/lib/core/history.zig:

- stored in ~/.mellon_history
- consecutive duplicates are not re-added
- max history length defaults to 1000

## Runtime Files and Data

Mellon reads/writes:

- ~/.mellonrc for config
- ~/.mellon_history for REPL history
- ~/.mellon_logs as error log root (when log writing is active)

Build artifacts:

- .zig-cache/
- zig-out/
- Mellon.app/ (macOS build script path)
- Mellon/ (Windows package folder from Python script)

## Project Layout

```text
mellon/
├── build.zig
├── build.zig.zon
├── README.md
├── docs/
│   ├── help.txt
│   ├── intro.txt
│   └── file_system_help.txt
├── build/
│   ├── main.py
│   ├── controller.py
│   ├── commands/
│   │   ├── base.py
│   │   ├── build.py
│   │   ├── clean.py
│   │   └── run.py
│   └── utils/
│       ├── args.py
│       ├── builders.py
│       ├── data_prep.py
│       └── system.py
└── src/
    ├── main.zig
    ├── root.zig
    └── lib/
        ├── base64.zig
        └── core/
            ├── _dev.zig
            ├── config.zig
            ├── error-handler.zig
            ├── file-system.zig
            ├── history.zig
            ├── io.zig
            ├── shell.zig
            └── utils.zig
```

## Notes and Current Limitations

- Some docs files in docs/ may lag behind current command routing when code changes quickly.
- Python build helper help output currently lists an audio command that is not wired in the controller.
- File-type validation limits file-system operations to a specific extension set.
- base64 help text in code still contains placeholder wording and may be refined later.
