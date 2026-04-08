const std = @import("std");
const Clr = @import("./utils.zig").Clr;
const Shell = @import("./shell.zig").Shell;
const Editor = @import("./utils.zig").Editor;
const History = @import("./history.zig").History;
const ErrorHandler = @import("./error-handler.zig").ErrorHandler;
const rc_file_name = @import("./utils.zig").rc_file_name;
const openEditor = @import("./utils.zig").openEditor;
const history_file_name = @import("./utils.zig").history_file_name;

const Prompt = struct {
    color: Clr,
    show_cwd: bool,
    symbol: []const u8,

    pub const DEFAULT = Prompt{ .color = .White, .show_cwd = true, .symbol = "⚡" };

    pub fn get(self: *const Prompt, allocator: std.mem.Allocator, Err: *ErrorHandler) ?[]const u8 {
        if (self.show_cwd) {
            const cwd = std.fs.cwd().realpathAlloc(allocator, ".") catch |err| {
                Err.handle(err, "Failed to get current working directory\n\n", false, true);
                return null;
            };
            defer allocator.free(cwd);
            return std.fmt.allocPrint(allocator, "{s} {s} ", .{ cwd, self.symbol }) catch |err| {
                Err.handle(err, "Failed to allocate memory for prompt\n\n", false, true);
                return null;
            };
        }
        return std.fmt.allocPrint(allocator, "{s} ", .{self.symbol}) catch |err| {
            Err.handle(err, "Failed to allocate memory for prompt\n\n", false, true);
            return null;
        };
    }
};

pub const Config = struct {
    history: History,
    Err: *ErrorHandler,
    editor: []const u8,
    log_dir: ?[]const u8,
    show_intro: bool = true,
    config_path: ?[]const u8,
    allocator: std.mem.Allocator,
    prompt: Prompt = Prompt.DEFAULT,
    prompt_symbol_owned: bool = false,

    pub fn init(allocator: std.mem.Allocator, Err: *ErrorHandler) Config {
        const home = std.posix.getenv("HOME") orelse "~";
        const editor = allocator.dupe(u8, "vim") catch "vim";
        const config_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, rc_file_name }) catch null;
        const log_dir_str = std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, history_file_name }) catch null;
        const log_dir = if (log_dir_str) |s| allocator.dupe(u8, s) catch null else null;
        const prompt_symbol = allocator.dupe(u8, Prompt.DEFAULT.symbol) catch Prompt.DEFAULT.symbol;
        var config = Config{
            .Err = Err,
            .editor = editor,
            .log_dir = log_dir,
            .allocator = allocator,
            .config_path = config_path,
            .history = History.init(allocator, Err, log_dir),
            .prompt = Prompt{ .color = Prompt.DEFAULT.color, .show_cwd = Prompt.DEFAULT.show_cwd, .symbol = prompt_symbol },
            .prompt_symbol_owned = @intFromPtr(prompt_symbol.ptr) != @intFromPtr(Prompt.DEFAULT.symbol.ptr),
        };
        config.load() catch |err| config.Err.handle(err, "Failed to load config file\n\n", false, true);
        config.save() catch |err| config.Err.handle(err, "Failed to save config file\n\n", false, true);
        return config;
    }

    pub fn controller(self: *Config, args: []const u8) void {
        if (args.len == 0) return self.edit() catch |err| {
            return self.Err.handle(err, "Failed to edit config file\n\n", false, true);
        };
        var arg_parts = std.mem.splitSequence(u8, args, " ");
        const func = Fn.get(arg_parts.first());
        switch (func) {
            .Help => return self.help(),
            .Set => return self.setCollection(arg_parts.rest()) catch |err| {
                return self.Err.handle(err, "Failed to set config values\n\n", false, true);
            },
            .Source => return self.load() catch |err| {
                return self.Err.handle(err, "Failed to load config file\n\n", false, true);
            },
            else => return self.edit() catch |err| {
                return self.Err.handle(err, "Failed to edit config file\n\n", false, true);
            },
        }
    }

    pub fn deinit(self: *Config) void {
        self.history.deinit();
        if (self.log_dir) |log_dir| self.allocator.free(log_dir);
        if (self.config_path) |config_path| self.allocator.free(config_path);
        self.allocator.free(self.editor);
        if (self.prompt_symbol_owned) self.allocator.free(self.prompt.symbol);
    }

    // Methods
    fn edit(self: *Config) !void {
        const config_path = self.config_path orelse return error.NoConfigPath;
        if (config_path.len == 0) return error.NoConfigPath;
        const editor = Editor.get(self.editor);
        openEditor(editor, config_path);
        try self.load();
    }

    fn help(self: *Config) void {
        openEditor(Editor.get(self.editor), "./docs/core/config.md");
    }

    fn load(self: *Config) !void {
        const config_path = self.config_path orelse return error.NoConfigPath;
        if (config_path.len == 0) return error.NoConfigPath;
        const file = try std.fs.openFileAbsolute(config_path, .{ .mode = .read_only });
        defer file.close();
        const file_size = try file.getEndPos();
        if (file_size == 0) return error.EmptyConfigFile;
        const buffer = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(buffer);
        const bytes_read = try file.readAll(buffer);
        if (bytes_read != file_size) return error.IncompleteRead;
        var lines = std.mem.splitScalar(u8, buffer, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0 or trimmed[0] == '#') continue;
            var parts = std.mem.splitScalar(u8, trimmed, '=');
            const key = std.mem.trim(u8, parts.first(), &std.ascii.whitespace);
            const value_str = std.mem.trim(u8, parts.rest(), &std.ascii.whitespace);
            if (value_str.len == 0) continue;
            try self.set(key, value_str);
        }
    }

    fn save(self: *const Config) !void {
        const config_path = self.config_path orelse return error.NoConfigPath;
        if (config_path.len == 0) return error.NoConfigPath;
        const file = try std.fs.createFileAbsolute(config_path, .{});
        defer file.close();
        var buffer: [2048]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buffer);
        const writer = stream.writer();
        try writer.print("# Mellon Configuration File\n", .{});
        try writer.print("editor={s}\n", .{self.editor});
        try writer.print("prompt_symbol={s}\n", .{self.prompt.symbol});
        try writer.print("prompt_color={s}\n", .{self.prompt.color.toString()});
        try writer.print("prompt_show_cwd={s}\n", .{if (self.prompt.show_cwd) "true" else "false"});
        try writer.print("log_dir={s}\n", .{self.log_dir orelse ""});
        try writer.print("show_intro={s}\n", .{if (self.show_intro) "true" else "false"});
        try file.writeAll(stream.getWritten());
    }

    fn set(self: *Config, key: []const u8, value: []const u8) !void {
        if (value.len == 0) return error.InvalidCommand;
        if (std.mem.eql(u8, key, "editor")) {
            const new = try self.allocator.dupe(u8, value);
            self.allocator.free(self.editor);
            self.editor = new;
            return;
        }

        if (std.mem.eql(u8, key, "prompt_symbol")) {
            const new = try self.allocator.dupe(u8, value);
            if (self.prompt_symbol_owned) self.allocator.free(self.prompt.symbol);
            self.prompt.symbol = new;
            self.prompt_symbol_owned = true;
            return;
        }
        if (std.mem.eql(u8, key, "prompt_color")) {
            const color = Clr.fromString(value) orelse return error.InvalidColor;
            self.prompt.color = color;
            return;
        }
        if (std.mem.eql(u8, key, "prompt_show_cwd")) {
            self.prompt.show_cwd = true;
            if (std.mem.eql(u8, value, "false")) self.prompt.show_cwd = false;
            return;
        }

        if (std.mem.eql(u8, key, "log_dir")) {
            const new = try self.allocator.dupe(u8, value);
            const old = self.log_dir;
            self.log_dir = new;
            self.history.log_dir = new;
            if (old) |log_dir| self.allocator.free(log_dir);
            return;
        }

        if (std.mem.eql(u8, key, "show_intro")) {
            self.show_intro = true;
            if (std.mem.eql(u8, value, "false")) self.show_intro = false;
            return;
        }
    }

    fn setCollection(self: *Config, args: []const u8) !void {
        var arg_parts = std.mem.splitSequence(u8, args, " ");
        while (arg_parts.next()) |pair| {
            var kv = std.mem.splitScalar(u8, pair, '=');
            const key = kv.first();
            const value = kv.rest();
            if (key.len == 0 or value.len == 0) continue;
            try self.set(key, value);
        }
        return try self.save();
    }
};

const Fn = enum {
    Set,
    Edit,
    Help,
    Source,
    Invalid,

    fn get(string: []const u8) Fn {
        if (std.mem.eql(u8, string, "set")) return .Set;
        if (std.mem.eql(u8, string, "edit")) return .Edit;
        if (std.mem.eql(u8, string, "source")) return .Source;
        if (std.mem.eql(u8, string, "help") or std.mem.eql(u8, string, "-h")) return .Help;
        return .Invalid;
    }
};
