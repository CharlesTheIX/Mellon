# Mellon TODO & Roadmap

## High Priority

### Core Features

- [ ] **Logger Module**: Add structured logging with levels (DEBUG, INFO, WARN, ERROR)
  - Log to file (`~/.mellon/logs/`)
  - Configurable log level in `.mellonrc`
  - Timestamp and color-coded messages
  - Optional verbose mode flag

- [ ] **Command Aliases**: User-defined command shortcuts in `.mellonrc`
  - Example: `alias ll="ls -la"`
  - Store in config and expand at runtime

- [ ] **Command Piping**: Support for `|` operator between commands
  - Example: `fs read --path=file.txt | grep "pattern"`
  - Capture stdout and pass to next command

- [ ] **Environment Variables**: Support for `$VAR` expansion
  - Read from system environment
  - Allow setting custom vars in config

### Performance

- [ ] **Command History Persistence**: Save history to `~/.mellon_history`
  - Load on startup
  - Save on exit
  - Configurable history size limit

- [ ] **Lazy Loading**: Defer module initialization until first use
  - Faster startup time
  - Reduce memory footprint

- [ ] **Process Pool**: Reuse shell process for multiple commands
  - Avoid spawn overhead
  - Benchmark impact on repeated commands

- [ ] **Caching**: Cache frequently accessed file paths and command lookups
  - PATH search results
  - Config file parsing
  - File system metadata

## Medium Priority

### User Experience

- [ ] **Tab Completion**: Autocomplete commands and file paths
  - Command names
  - File paths (files and directories)
  - Config keys

- [ ] **Command History Search**: Ctrl+R reverse search
  - Fuzzy matching
  - Show matches as you type

- [ ] **Multi-line Input**: Support for `\` continuation
  - Handle long commands across multiple lines
  - Visual indicator for continuation

- [ ] **Output Paging**: Automatic paging for long output
  - Use `less` or similar
  - Configurable threshold

- [ ] **Session Management**: Save and restore REPL sessions
  - Save working directory, history, and environment
  - Quick resume from last session

### File System Enhancements

- [ ] **Batch Operations**: Multiple file operations in one command
  - `fs copy --from=*.txt --to=backup/`
  - Glob pattern support

- [ ] **File Watching**: Monitor files for changes
  - `fs watch --path=./src`
  - Trigger commands on change

- [ ] **Archive Support**: Handle `.zip`, `.tar`, `.gz` files
  - Extract, compress, list contents
  - Integrate with existing fs commands

- [ ] **Diff Command**: Compare files and directories
  - Side-by-side or unified diff
  - Color-coded output

### Configuration

- [ ] **Theme Support**: Customizable color schemes
  - Predefined themes (dark, light, solarized)
  - User-defined RGB values

- [ ] **Key Bindings**: Configurable keyboard shortcuts
  - Vim/Emacs modes
  - Custom key mappings in `.mellonrc`

- [ ] **Plugin System**: Load external Zig modules
  - Plugin directory (`~/.mellon/plugins/`)
  - Auto-discovery and loading
  - Plugin API for registering commands

## Low Priority

### Documentation

- [ ] **Man Page**: Create comprehensive man page
  - Installation instructions
  - Command reference
  - Examples

- [ ] **Interactive Tutorial**: Built-in tutorial mode
  - `mellon tutorial`
  - Step-by-step guide for new users

- [ ] **API Documentation**: Generate docs from code comments
  - Use `zig doc` or similar
  - Host on GitHub Pages

### Testing & CI

- [ ] **Unit Tests**: Add test coverage for all modules
  - Config parsing
  - Command routing
  - File operations

- [ ] **Integration Tests**: End-to-end testing
  - REPL interaction simulation
  - Command execution validation

- [ ] **CI Pipeline**: Automated build and test
  - GitHub Actions
  - Multiple platform testing (macOS, Linux, Windows)
  - Release automation

### Advanced Features

- [ ] **Scripting Mode**: Execute Mellon scripts
  - `.mellon` file extension
  - Execute with `mellon script.mellon`
  - Support for variables, loops, conditionals

- [ ] **Remote Execution**: SSH integration
  - `mellon remote user@host command`
  - Secure credential storage

- [ ] **Background Jobs**: Run commands in background
  - `command &` syntax
  - Job control (list, kill, foreground)

- [ ] **Command Scheduler**: Cron-like scheduling
  - Schedule commands to run at specific times
  - Stored in config or separate schedule file

- [ ] **Network Commands**: HTTP requests, downloads
  - `net get URL`
  - `net post URL --data=...`

- [ ] **Database Interface**: Query databases from REPL
  - SQLite support initially
  - Pluggable drivers for other databases

## Performance Benchmarks to Add

- [ ] Command execution overhead vs native shell
- [ ] Memory usage tracking over time
- [ ] Startup time optimization
- [ ] History search performance with large datasets
- [ ] File operation throughput

## Known Issues

- [ ] Fix: Benchmark command recursion depth
- [ ] Fix: Error handling for nested commands
- [ ] Fix: Handle very long input lines (>1024 chars)
- [ ] Fix: Password prompt shows input on some terminals
- [ ] Improve: Error messages for invalid config values

## Infrastructure

- [ ] **Cross-platform Support**: Windows and Linux compatibility
  - Abstract terminal operations
  - Handle path separators
  - Test on multiple platforms

- [ ] **Package Manager Integration**: Homebrew, apt, etc.
  - Formula/package files
  - Distribution automation

- [ ] **Dockerfile Optimization**: Multi-stage builds
  - Smaller image size
  - Faster builds

---

**Note**: Items marked with 🔥 are high-impact features that would significantly improve the user experience.

**Contributions**: Feel free to pick any item and open a PR! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
