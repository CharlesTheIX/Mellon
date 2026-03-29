MELLON HELP

USAGE
	mellon
	mellon [command] [args]

TOP-LEVEL COMMANDS
	help                     Show this help page
	exit | :q                Exit Mellon
	repl                     Enter REPL mode
	benchmark | bench        Time a Mellon command
	config                   Open the config file in your editor
	config edit              Open the config file in your editor
	config set k=v [...]     Update config values and save them
	config source            Reload config from disk
	file-system | fs         File helpers
	search | s               Run ripgrep with --vimgrep

FILE SYSTEM
	fs help
	fs read    --path=FILE
	fs write   --path=FILE [--editor=vim|nvim|code]
	fs copy    --from=SRC --to=DEST
	fs delete  --path=FILE
	fs get_abs --path=PATH

CONFIG
	File: ~/.mellonrc

	Supported keys:
	editor=vim|nvim|code
	prompt=TEXT
	show_intro=true|false
	show_cwd=true|false

SEARCH
	search QUERY
	s QUERY

	Notes:
	Requires rg in PATH.
	Output comes from: rg --vimgrep QUERY

SHELL FALLBACK
	If a command is not built in, Mellon looks it up in PATH and runs it.

REPL NOTES
	Up and down arrows navigate history.
	Left and right arrows move the cursor.
	Ctrl+C clears the current line.
	History is stored in ~/.mellon_history.

LIMITS
	File operations only accept these file types right now:
	js, json, md, ts, txt, z
