# Mellon

Mellon is a small interactive shell written in Zig. It runs as a REPL, dispatches a handful of built-in commands, falls back to external programs found in `PATH`, keeps command history, and exposes simple helpers for config, search, benchmarking, and file operations.

The documentation in this repository now tracks the code that exists today instead of older planned features.

## What Mellon Does

- interactive terminal REPL
- configurable prompt and intro screen
- built-in commands for help, config, search, file operations, and benchmarking
- shell fallback for non-built-in commands
- command history saved to `~/.mellon_history`
- config stored in `~/.mellonrc`
- optional error logs written under `~/.mellon_logs`

## Build

Requirements:

- Zig 0.15.2 or newer
- Unix-like terminal environment
- `rg` in `PATH` if you want to use the `search` command

Build:

```bash
zig build
```

Run:

```bash
zig build run
```

Installed binary path:

```text
zig-out/bin/mellon
```

## Starting Mellon

Run Mellon with no arguments to enter the REPL:

```bash
mellon
```

The prompt defaults to `⚡`. When `show_cwd=true`, the prompt includes the current working directory.

The codebase is also structured to route commands passed on the command line through the same top-level controller.

## Top-Level Commands

Mellon recognizes these commands:

- `help`
- `exit` or `:q`
- `repl`
- `benchmark` or `bench`
- `config`
- `file-system` or `fs`
- `search` or `s`

If a command is not built in, Mellon attempts to find it in `PATH` and execute it as a child process.

## Command Reference

### Help

Show the bundled help page:

```text
help
```

### Exit

Leave the session:

```text
exit
:q
```

### Benchmark

Benchmark a Mellon-routed command:

```text
benchmark ls -la
bench fs read --path=./README.md
```

Mellon prints elapsed time in milliseconds and nanoseconds.

### Search

Search delegates to ripgrep using `rg --vimgrep`:

```text
search prompt
s FileSystem
```

Notes:

- `rg` must be installed
- the query string is passed directly to ripgrep
- output uses ripgrep's vimgrep format

### Config

Config lives at `~/.mellonrc`.

Common commands:

```text
config
config edit
config set prompt=$
config set editor=code show_intro=false show_cwd=false
config source
```

Config keys handled by the current code:

- `editor`
- `prompt`
- `show_intro`
- `show_cwd`

The config file also contains `log_dir`, which Mellon uses for error logs.

### File System

The file-system command group provides:

```text
fs help
fs read --path=./README.md
fs write --path=./notes.md --editor=code
fs copy --from=./a.txt --to=./b.txt
fs delete --path=./old.txt
fs get_abs --path=~/projects
```

Available subcommands:

- `help`
- `read`
- `write`
- `copy`
- `delete`
- `get_abs`

Current limitation:

- Mellon only accepts these file extensions for file operations: `js`, `json`, `md`, `ts`, `txt`, `z`

### Shell Fallback

Examples of commands handled through shell fallback:

```text
pwd
ls -la
git status
clear
```

Special behaviour exists for:

- `pwd`
- `clear`

All other non-built-in commands are executed as child processes.

## REPL Behaviour

The REPL currently supports:

- editable input line
- left and right arrow cursor movement
- up and down arrow history navigation
- Ctrl+C to clear the current line
- colored terminal output

History details:

- stored at `~/.mellon_history`
- duplicate consecutive commands are skipped
- history is capped at 1000 entries

## Runtime Files

Mellon creates or uses these files:

- `~/.mellonrc`
- `~/.mellon_history`
- `~/.mellon_logs/error.log` and related log files when error logging is enabled

## Project Layout

```text
mellon/
├── build.zig
├── build.zig.zon
├── docs/
│   ├── help.txt
│   ├── intro.txt
│   └── file_system_help.txt
├── src/
│   ├── main.zig
│   ├── root.zig
│   └── lib/
│       ├── search.zig
│       └── core/
│           ├── config.zig
│           ├── error-handler.zig
│           ├── file-system.zig
│           ├── history.zig
│           ├── io.zig
│           ├── shell.zig
│           └── utils.zig
└── zig-out/
```

## Architecture

High-level flow:

1. `src/main.zig` builds the runtime objects.
2. `src/root.zig` routes top-level commands.
3. `src/lib/core/io.zig` manages input, output, colors, and history-aware editing.
4. `src/lib/core/config.zig` loads and saves `~/.mellonrc`.
5. `src/lib/core/file-system.zig` implements file helpers.
6. `src/lib/core/shell.zig` executes external commands.
7. `src/lib/search.zig` delegates search to ripgrep.

## Documentation Files

If you change user-visible behaviour, update these files together:

- `README.md`
- `docs/help.txt`
- `docs/intro.txt`
- `docs/file_system_help.txt`
  Mellon.controller() - Routes commands
  ↓
  ├─ "exit" / ":q" → Exit program
  ├─ "file-system" / "fs" → FileSystem.controller()
  ├─ "help" → Display help
  ├─ "repl" → Already in REPL mode
  └─ Other → Shell.controller()

````

## Deeper Dive

### Core Components

#### 1. Main Application (`src/main.zig`)

The entry point initializes the Mellon application and handles command-line arguments:

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const cli_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    // Special mode: NaseLaska game
    if (args.len > 1 and std.mem.eql(u8, args[1], "naselaska")) {
        var nase_laska = NaseLaska.init(allocator);
        defer nase_laska.deinit();
        nase_laska.start() catch std.debug.print("❌ NaseLaska failed\n\n", .{});
        return std.process.exit(0);
    }

    var config = Config.init(allocator);
    defer config.deinit();

    var stdin_buffer: [1024]u8 = undefined;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdin_reader = std.fs.File.stdin().readerStreaming(&stdin_buffer);
    var io = IO.init(allocator, &stdin_reader, &stdout_writer, &config);
    defer io.deinit();

    var mellon = Mellon.init(&io, &config);
    defer mellon.deinit();
    return try mellon.run(cli_args);
}
````

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
| `benchmark`   | `bench` | Run a timed command           |
| `exit`        | `:q`    | Exit the application          |
| `file-system` | `fs`    | Access file system operations |
| `config`      | -       | Configure prompt/editor/intro |
| `help`        | -       | Display help information      |
| `repl`        | -       | Enter interactive REPL mode   |
| `naselaska`   | -       | Launch NaseLaska GUI mode     |
| `(other)`     | -       | Passed to shell executor      |

`help` prints the contents of `docs/help.txt`.
If `show_intro` is enabled, REPL startup displays `docs/intro.txt`.

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

#### History Module (`src/lib/core/history.zig`)

Manages command history with persistent storage:

- **Persistent Storage**: Automatically saves to `~/.mellon_history`
- **Arrow Navigation**: Use ↑/↓ to navigate through previous commands
- **Deduplication**: Consecutive duplicate commands are not stored
- **Size Limit**: Default maximum of 1000 commands (configurable)
- **Auto-save**: History is saved after each command for durability

History features:

- Loads on startup from `~/.mellon_history`
- Saves on exit and after each command
- Trims old entries when max size is reached
- Preserves history across sessions

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
- `show_cwd` (true/false)

Example:

```
# ~/.mellonrc
editor=vim
prompt=⚡
show_intro=true
show_cwd=true
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
