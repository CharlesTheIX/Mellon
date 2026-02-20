# Mellon 🧙

A high-performance shell-like REPL application written in [Zig](https://ziglang.org/). Mellon provides an interactive command interface with built-in support for file system operations and shell command execution.

## Features

- **Interactive REPL**: Command-line interface with a `⚡` prompt
- **Shell Integration**: Execute standard shell commands directly
- **File System Operations**: Built-in commands for reading, writing, copying, and deleting files
- **Colored Output**: Color-coded messages for better user experience (Red, Green, Blue, Cyan, Magenta, Yellow, White)
- **Memory Efficient**: Written in Zig for fast execution and minimal resource usage

## Table of Contents

- [Setup](#setup)
  - [Prerequisites](#prerequisites)
  - [Building from Source](#building-from-source)
- [Understanding the Project](#understanding-the-project)
  - [Project Structure](#project-structure)
  - [Architecture Overview](#architecture-overview)
- [Deeper Dive](#deeper-dive)
  - [Core Components](#core-components)
  - [Command System](#command-system)
  - [Module Details](#module-details)
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

## Understanding the Project

### Project Structure

```
mellon/
├── build.zig              # Zig build configuration
├── build.zig.zon          # Zig package manifest
├── src/
│   ├── main.zig           # Application entry point
│   ├── root.zig           # Main Mellon struct and command controller
│   └── lib/
│       ├── io.zig         # Input/Output and colored text handling
│       ├── shell.zig      # Shell command execution
│       └── file-system.zig # File operations (read, write, copy, delete)
├── zig-out/
│   └── bin/
│       └── mellon         # Compiled executable
└── README.md              # This file
```

### Architecture Overview

Mellon follows a modular architecture with three main components working together:

1. **IO Module**: Handles input/output with color support
2. **Shell Module**: Executes shell commands transparently
3. **FileSystem Module**: Provides file manipulation utilities

The main `Mellon` struct orchestrates these components and provides the command controller that routes user input to the appropriate handler.

```
User Input (⚡ prompt)
        ↓
   Mellon.run()
        ↓
   Mellon.controller() - Routes commands
        ↓
   ├─ "exit" / ":q" → Exit program
   ├─ "file_system" / "fs" → FileSystem.controller()
   ├─ "help" → Display help
   └─ Other → Shell.controller()
```

## Deeper Dive

### Core Components

#### 1. Main Application (`src/main.zig`)

The entry point initializes the Mellon application with buffered I/O:

```zig
pub fn main() !void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdout_buffer: [1024]u8 = undefined;
    var mellon = Mellon.init(&stdin_reader, &stdout_writer);
    try mellon.run();
}
```

#### 2. Root Module (`src/root.zig`)

The `Mellon` struct is the core orchestrator:

- **`init()`**: Initializes IO, Shell, and FileSystem modules
- **`run()`**: Main REPL loop that continuously reads and processes commands
- **`controller()`**: Routes commands to appropriate handlers
- **`deinit()`**: Cleanup and resource deallocation

### Command System

Mellon recognizes these built-in commands:

| Command       | Aliases | Function                      |
| ------------- | ------- | ----------------------------- |
| `exit`        | `:q`    | Exit the application          |
| `file_system` | `fs`    | Access file system operations |
| `help`        | -       | Display help information      |
| `(other)`     | -       | Passed to shell executor      |

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

Access file operations via `fs` or `file_system`:

```
⚡ fs read --path=./README.md
⚡ fs write --path=./newfile.txt --editor=nvim
⚡ fs copy --from=./file1.txt --to=./file2.txt
⚡ fs delete --path=./oldfile.txt
⚡ fs get-abs --path=~/Documents
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
- Validates file types (`.txt`, `.md`, `.json`)

Example absolute path conversion:

```
~/Documents/file.md → /Users/davidcharles/Documents/file.md
../config.json → /Users/davidcharles/projects/config.json
./data.txt → /Users/davidcharles/repos/mellon/data.txt
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

#### Simple Alias

```bash
# Open ~/.zshrc
nano ~/.zshrc

# Add this line
alias mellon="/usr/local/bin/mellon"

# Reload configuration
source ~/.zshrc
```

#### Custom Aliases with Options

```bash
# ~/.zshrc

# Direct mellon command
alias m="mellon"

# Mellon with specific working directory
alias mdev="cd ~/repos/mellon && mellon"

# Mellon for different projects
alias mproject="cd ~/repos/my-project && mellon"
```

#### Enhanced Shell Configuration Example

Here's a complete `.zshrc` configuration for Mellon:

```bash
# ~/.zshrc

# ... other zsh configuration ...

# === Mellon Configuration ===

# Add Mellon binary to PATH
export PATH="/usr/local/bin:$PATH"

# Mellon aliases
alias m="mellon"           # Quick launch
alias mel="mellon"         # Full name
alias mdev="mellon"        # Development instance

# Optional: Color prompt in mellon
alias mellon="/usr/local/bin/mellon && echo '✨ Mellon closed'"

# ... rest of zsh configuration ...
```

### Running Mellon

After setup, simply type:

```bash
mellon
```

Or use your alias:

```bash
m
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
Exiting with status: 0
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
