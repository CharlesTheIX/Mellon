MELLON FILE SYSTEM HELP

USAGE
    fs help
    fs read --path=FILE
    fs write --path=FILE [--editor=vim|nvim|code]
    fs copy --from=SRC --to=DEST
    fs delete --path=FILE
    fs get_abs --path=PATH

COMMANDS
    read
        Read a supported file and print its contents.

    write
        Open a supported file in an editor.
        If --editor is omitted, Mellon uses the editor from config.

    copy
        Copy one supported file to another path.

    delete
        Delete a supported file.

    get_abs
        Expand a path to an absolute path.

PATH RULES
    Absolute paths are used as-is.
    Paths beginning with ~ expand from HOME.
    Relative paths are resolved from the current working directory.

SUPPORTED FILE TYPES
    js
    json
    md
    ts
    txt
    z

EXAMPLES
    fs read --path=./README.md
    fs write --path=./notes.md --editor=code
    fs copy --from=./draft.txt --to=./draft.backup.txt
    fs delete --path=./old.md
    fs get_abs --path=~/projects/mellon

NOTES
    Some subcommands will prompt for missing arguments.
    The write command opens an editor rather than writing content directly.