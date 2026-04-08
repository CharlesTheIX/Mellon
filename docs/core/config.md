# Config

Usage: `config [command] [options]`

Commands:

- `set --key=value [--key=value ...]` - Set multiple config values at once
- `edit` - Open the config file in the editor
- `source` - Reload the config from the file

Options:

- `--key=value` - Set a specific config value (used with 'set' command)

Config Keys:

- `editor` - The editor to use for editing files (default: vim)
- `prompt_symbol` - The prompt symbol to use (default: ⚡)
- `prompt_color` - The color of the prompt (default: White)
- `prompt_show_cwd` - Whether to show the current working directory in the prompt (default: true)
- `log_dir` - Directory to store log files (default: ~/.mellon_logs)
- `show_intro` - Whether to show the intro message on startup (default: true)
