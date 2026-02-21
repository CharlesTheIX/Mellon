# Mellon 🧙

A high-performance shell-like REPL application written in [Zig](https://ziglang.org/). Mellon provides an interactive command interface with built-in support for file system operations and shell command execution.

## Features

- **Dual Mode Operation**: Use as a CLI tool for single commands or enter REPL mode for interactive commands
- **Interactive REPL**: Command-line interface with a configurable prompt (defaults to `⚡`)
- **CLI Tool**: Execute individual commands directly without entering REPL mode
- **Shell Integration**: Execute standard shell commands directly
- **File System Operations**: Built-in commands for reading, writing, copying, and deleting files
- **Configurable Runtime**: `config` command and `~/.mellonrc` support for editor, prompt, and intro display
- **Command History**: Arrow-key navigation in REPL input
- **Colored Output**: Color-coded messages for better user experience (Red, Green, Blue, Cyan, Magenta, Yellow, White)

## Table of Contents

- [Setup](#setup)
  - [Prerequisites](#prerequisites)
  - [Building from Source](#building-from-source)
- [Usage](#usage)
  - [CLI Mode](#cli-mode)
  - [REPL Mode](#repl-mode)
- [Understanding the Project](#understanding-the-project)
  - [Project Structure](#project-structure)
  - [Architecture Overview](#architecture-overview)
- [Deeper Dive](#deeper-dive)
  - [Core Components](#core-components)
  - [Command System](#command-system)
  - [Module Details](#module-details)
    - [Configuration](#configuration)
- [Using the Binary](#using-the-binary)
  - [Adding to PATH](#adding-to-path)
  - [Creating Aliases](#creating-aliases)

## Setup

### Prerequisites

- **Zig** (v0.15.2 or later) - [Download Zig](https://ziglang.org/download/)
- **macOS** (or compatible Unix-like system)

Verify your Zig installation:

```bash
zig version
```

### Building from Source

1. **Clone or navigate to the project directory**:

```bash
cd /Users/davidcharles/repos/mellon
```

2. **Build the project**:

```bash
zig build
```

3. **Run the application**:

```bash
zig build run
```

The compiled binary will be available at:

```
zig-out/bin/mellon
```

## Usage

### CLI Mode

Use Mellon to execute single commands from your shell without entering interactive mode:

```bash
# Get current working directory
mellon pwd

# List directory contents
mellon ls -la

# Execute shell commands
mellon whoami

# Use file system operations
mellon fs read --path=./README.md
mellon fs write --path=./newfile.txt --editor=nvim
mellon fs copy --from=./file1.txt --to=./file2.txt
mellon fs delete --path=./oldfile.txt
mellon fs get_abs --path=~/Documents

# Configure settings
mellon config set editor=code prompt=⚡ show_intro=false
mellon config source
mellon config
```

CLI mode is perfect for:

- Scripting and automation
- Single command execution
- Integration with other tools
- Shell pipelines

### REPL Mode

Enter interactive mode by running Mellon without arguments:

```bash
mellon
```

You'll see the Mellon prompt (default is `⚡`).

In REPL mode, execute commands interactively:

```
⚡ pwd
/Users/davidcharles/repos/mellon

⚡ ls
build.zig               src
build.zig.zon           zig-out
README.md

⚡ fs read --path=./README.md

⚡ help

⚡ exit
Goodbye! 👋
```

Or explicitly enter REPL mode from CLI:

```bash
mellon repl
```

REPL mode is perfect for:

- Interactive exploration and testing
- Continuous command execution without restarting
- Development and debugging workflows

## Understanding the Project

### Project Structure

```
mellon/
├── build.zig              # Zig build configuration
├── build.zig.zon          # Zig package manifest
├── docs/
│   └── test.md             # Intro/help text shown in REPL
├── src/
│   ├── main.zig           # Application entry point
│   ├── root.zig           # Main Mellon struct and command controller
│   └── lib/
│       ├── config.zig      # Config handling and .mellonrc parsing
│       ├── history.zig     # In-memory REPL history
│       ├── io.zig         # Input/Output and colored text handling
│       ├── shell.zig      # Shell command execution
│       └── file-system.zig # File operations (read, write, copy, delete)
├── zig-out/
│   └── bin/
│       └── mellon         # Compiled executable
└── README.md              # This file
```

### Architecture Overview

Mellon follows a modular architecture with three main components working together. The application supports two execution modes:

**CLI Mode** (single command execution):

```
$ mellon <command> [args]
        ↓
   Mellon.run(args)
        ↓
   Mellon.controller() - Routes command
        ↓
   └─ Execute and exit
```

**REPL Mode** (interactive):

```
$ mellon
        ↓
   Mellon.run(empty args)
        ↓
   Mellon.repl() - Interactive loop
        ↓
   User Input (⚡ prompt)
        ↓
   Mellon.controller() - Routes commands
        ↓
     ├─ "exit" / ":q" → Exit program
     ├─ "file-system" / "fs" → FileSystem.controller()
     ├─ "help" → Display help
     ├─ "repl" → Already in REPL mode
     └─ Other → Shell.controller()
```

## Deeper Dive

### Core Components

#### 1. Main Application (`src/main.zig`)

The entry point initializes the Mellon application and handles command-line arguments:

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
     defer _ = gpa.deinit();

     var config = Config.init(allocator);
     defer config.deinit();

     var history = History.init(allocator);
     defer history.deinit();

     var stdin_buffer: [1024]u8 = undefined;
     var stdout_buffer: [1024]u8 = undefined;
     var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
     var stdin_reader = std.fs.File.stdin().readerStreaming(&stdin_buffer);
     var io = IO.init(&stdin_reader, &stdout_writer, &history);
     defer io.deinit();

     var mellon = Mellon.init(&io, &config);
     defer mellon.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Skip program name (args[0]) and pass remaining to run()
    const cli_args = if (args.len > 1) args[1..] else &[_][]const u8{};
    try mellon.run(cli_args);
}
```

#### 2. Root Module (`src/root.zig`)

The `Mellon` struct is the core orchestrator:

- **`init()`**: Initializes IO, Shell, and FileSystem modules
- **`run(args[])`**: Accepts command-line arguments; enters REPL mode if no args, otherwise executes CLI command
- **`repl()`**: Interactive REPL loop that continuously reads and processes commands
- **`controller()`**: Routes commands to appropriate handlers
- **`deinit()`**: Cleanup and resource deallocation

The `run()` method determines execution mode:

- **No arguments**: Enters REPL mode via `repl()`
- **"repl" command**: Explicitly enters REPL mode via `repl()`
- **Other arguments**: Executes as CLI command and exits

### Command System

Mellon recognizes these built-in commands:

| Command       | Aliases | Function                      |
| ------------- | ------- | ----------------------------- |
| `exit`        | `:q`    | Exit the application          |
| `file-system` | `fs`    | Access file system operations |
| `config`      | -       | Configure prompt/editor/intro |
| `help`        | -       | Display help information      |
| `repl`        | -       | Enter interactive REPL mode   |
| `(other)`     | -       | Passed to shell executor      |

`help` prints the contents of `docs/test.md`.

#### Shell Commands

Any command not recognized as a built-in is forwarded to the shell:

```
⚡ pwd
/Users/davidcharles/repos/mellon

⚡ ls -la
total 24
...

⚡ whoami
davidcharles
```

#### File System Commands

_The default text editor is Vim, but you can choose Nvim or VS Code when prompted._

Access file operations via `fs` or `file-system`:

```
⚡ fs read --path=./README.md
⚡ fs write --path=./newfile.txt --editor=nvim
⚡ fs copy --from=./file1.txt --to=./file2.txt
⚡ fs delete --path=./oldfile.txt
⚡ fs get_abs --path=~/Documents
```

### Module Details

#### IO Module (`src/lib/io.zig`)

Provides colored output and input handling:

- **`Clr` enum**: Color definitions (Blue, Cyan, Green, Magenta, Red, White, Yellow)
- **`print(msg, color)`**: Print colored messages using ANSI escape codes
- **`deinit()`**: Flush output buffer

Color output uses standard ANSI escape sequences:

```
\x1b[34m  (Blue)
\x1b[32m  (Green)
\x1b[31m  (Red)
\x1b[0m   (Reset)
```

Example usage:

```zig
try io.print("✅ Success!", .Green);
try io.print("❌ Error!", .Red);
```

#### Shell Module (`src/lib/shell.zig`)

Executes shell commands:

- **`clear()`**: Clear the terminal screen
- **`pwd()`**: Print working directory (with `-L` flag for logical paths)
- **`controller(command, args)`**: Execute arbitrary shell commands
- **`openEditor(editor, path)`**: Open file in specified editor (Nvim or VS Code)

Key features:

- Validates commands exist in PATH before execution
- Uses `std.process.Child` to spawn and wait for processes
- Supports argument parsing and passing

Implementation detail - command validation:

```zig
fn getCommandIsInPATH(command: []const u8) ![]const u8
```

This function searches Unix PATH to ensure the command exists before execution.

#### FileSystem Module (`src/lib/file-system.zig`)

Handles file operations:

- **`read(path)`**: Read and display file contents
- **`write(path, editor)`**: Create file in editor (Nvim or VS Code)
- **`copy(from, to)`**: Copy files between locations
- **`delete(path)`**: Remove files
- **`getAbs(path)`**: Convert relative paths to absolute paths

Path handling features:

- Supports `~` expansion (home directory)
- Supports relative paths (`.`, `..`)
- Supports absolute paths (`/path/to/file`)
- Validates file types (`.txt`, `.md`, `.json`, `.js`, `.ts`)
- Rejects files larger than 10MB when reading

Example absolute path conversion:

```
~/Documents/file.md → /Users/davidcharles/Documents/file.md
../config.json → /Users/davidcharles/projects/config.json
./data.txt → /Users/davidcharles/repos/mellon/data.txt
```

## Configuration

Mellon reads configuration from `~/.mellonrc` on startup. You can edit it directly or use the `config` command.

Supported keys:

- `editor` (vim, nvim, code)
- `prompt` (single token; spaces are not supported)
- `show_intro` (true/false)

Example:

```
# ~/.mellonrc
editor=vim
prompt=⚡
show_intro=true
```

## Using the Binary

Once you've built Mellon, you can install it globally for easy access.

### Adding to PATH

The compiled binary is located at `zig-out/bin/mellon`. You have two options:

#### Option 1: Copy to System Binary Directory (Recommended)

```bash
sudo cp zig-out/bin/mellon /usr/local/bin/
```

Verify installation:

```bash
which mellon
mellon
```

#### Option 2: Add Project Directory to PATH

Edit your shell configuration file (`.zshrc` for Zsh):

```bash
# Open the file
nano ~/.zshrc

# Add this line
export PATH="/Users/davidcharles/repos/mellon/zig-out/bin:$PATH"

# Save and reload
source ~/.zshrc
```

### Creating Aliases

Aliases make it even easier to launch Mellon. Add these to your `~/.zshrc`:

#### Simple Aliases

```bash
# Open ~/.zshrc
nano ~/.zshrc

# Add these lines
alias mellon="/usr/local/bin/mellon"
alias m="mellon"                    # Quick access to REPL
alias mls="mellon ls"               # Quick ls command
alias mpwd="mellon pwd"             # Quick pwd command
alias mfs="mellon fs"               # Quick file system access

# Reload configuration
source ~/.zshrc
```

#### Usage with Aliases

```bash
# REPL mode
m

# CLI mode with aliases
mls -la
mpwd
mfs read --path=./README.md
```

### Running Mellon

After setup, you can use Mellon in two ways:

#### Interactive REPL Mode

Simply type `mellon` with no arguments:

```bash
mellon
```

You'll see the Mellon prompt:

```
⚡
```

Type commands to interact:

```
⚡ pwd
/Users/davidcharles/repos/mellon

⚡ ls
build.zig               src
build.zig.zon           zig-out
README.md

⚡ fs read --path=./README.md

⚡ exit
Goodbye! 👋
```

#### CLI Command Mode

Execute commands directly without entering REPL:

```bash
mellon pwd
/Users/davidcharles/repos/mellon

mellon ls -la
total 32
drwxr-xr-x  7 user  group  224 Feb 21 10:30 .
drwxr-xr-x  3 user  group   96 Feb 21 09:15 ..
...

mellon fs read --path=./README.md
[file contents]
```

Use your alias for quick access:

```bash
m pwd
m ls
m fs read --path=./file.txt
```

## Development

To rebuild after making changes:

```bash
zig build
```

To run with debug output:

```bash
zig build run
```

To format code:

```bash
zig fmt src/
```

## Performance

Mellon is optimized for performance:

- **Compiled Language**: Zig compiles to native machine code
- **Minimal Runtime**: Zero garbage collection overhead
- **Efficient Memory**: Stack allocation for buffers where possible
- **Fast Startup**: Instant initialization and command processing

## Troubleshooting

### Binary not found after adding to PATH

- Verify the binary exists: `ls -la zig-out/bin/mellon`
- Reload your shell: `source ~/.zshrc`
- Check PATH variable: `echo $PATH`

### Permission denied when running mellon

```bash
chmod +x /usr/local/bin/mellon
```

### Build fails

- Ensure Zig is installed: `zig version`
- Update Zig to the latest version
- Clear build cache: `rm -rf .zig-cache zig-out && zig build`

## License

Mellon is an open-source project. Check LICENSE file for details.

## Contributing

Contributions are welcome! Please ensure code follows Zig conventions and passes `zig fmt`.

---

**Happy coding with Mellon! 🧙‍♂️**
