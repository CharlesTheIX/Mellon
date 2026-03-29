const std = @import("std");
const Shell = @import("./shell.zig").Shell;
const Editor = @import("./file-system.zig").Editor;
const ErrorHandler = @import("./error-handler.zig").ErrorHandler;
const openEditor = @import("./shell.zig").openEditor;

pub const Config = struct {
    Err: *ErrorHandler,
    prompt: []const u8,
    editor: []const u8,
    log_dir: ?[]const u8,
    show_cwd: bool = true,
    show_intro: bool = true,
    config_path: ?[]const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, Err: *ErrorHandler) Config {
        const home = std.posix.getenv("HOME") orelse "~";
        const log_dir = std.fmt.allocPrint(allocator, "{s}/.mellon_logs", .{home}) catch null;
        const config_path = std.fmt.allocPrint(allocator, "{s}/.mellonrc", .{home}) catch null;
        const prompt = allocator.dupe(u8, "⚡") catch "⚡";
        const editor = allocator.dupe(u8, "vim") catch "vim";
        var config = Config{
            .Err = Err,
            .prompt = prompt,
            .editor = editor,
            .log_dir = log_dir,
            .allocator = allocator,
            .config_path = config_path,
        };
        config.load() catch |err| config.Err.handle(err, "Failed to load config file\n\n", false, true);
        config.save() catch |err| config.Err.handle(err, "Failed to save config file\n\n", false, true);
        return config;
    }

    // Instances Methods
    pub fn controller(self: *Config, args: []const u8) void {
        if (args.len == 0) return self.edit() catch |err| return self.Err.handle(
            err,
            "Failed to edit config file\n\n",
            false,
            true,
        );
        var arg_parts = std.mem.splitSequence(u8, args, " ");
        const func = Fn.get(arg_parts.first());
        switch (func) {
            .Set => {
                while (arg_parts.next()) |pair| {
                    var kv = std.mem.splitScalar(u8, pair, '=');
                    const key = kv.first();
                    const value = kv.rest();
                    if (key.len == 0 or value.len == 0) continue;
                    self.set(key, value) catch |err| {
                        self.Err.handle(err, "Failed to set config value\n\n", false, true);
                        continue;
                    };
                }
                return self.save() catch |err| return self.Err.handle(
                    err,
                    "Failed to save config file\n\n",
                    false,
                    true,
                );
            },
            .Source => return self.load() catch |err| return self.Err.handle(
                err,
                "Failed to load config file\n\n",
                false,
                true,
            ),
            else => return self.edit() catch |err| return self.Err.handle(
                err,
                "Failed to edit config file\n\n",
                false,
                true,
            ),
        }
    }

    pub fn deinit(self: *Config) void {
        self.allocator.free(self.editor);
        self.allocator.free(self.prompt);
        if (self.log_dir) |log_dir| self.allocator.free(log_dir);
        if (self.config_path) |config_path| self.allocator.free(config_path);
    }

    pub fn getFullPrompt(self: *const Config) []const u8 {
        if (self.show_cwd) {
            const cwd = std.fs.cwd().realpathAlloc(self.allocator, ".") catch |err| {
                self.Err.handle(err, "Failed to get current working directory\n\n", false, true);
                return "";
            };
            defer self.allocator.free(cwd);
            return std.fmt.allocPrint(self.allocator, "{s} {s} ", .{ cwd, self.prompt }) catch |err| {
                self.Err.handle(err, "Failed to allocate memory for prompt\n\n", false, true);
                return "";
            };
        }
        return std.fmt.allocPrint(self.allocator, "{s} ", .{self.prompt}) catch |err| {
            self.Err.handle(err, "Failed to allocate memory for prompt\n\n", false, true);
            return "";
        };
    }

    // Private Methods
    fn edit(self: *Config) !void {
        const config_path = self.config_path orelse return error.NoConfigPath;
        if (config_path.len == 0) return error.NoConfigPath;
        const editor = Editor.get(self.editor);
        openEditor(editor, config_path);
        try self.load();
    }

    fn load(self: *Config) !void {
        const config_path = self.config_path orelse return error.NoConfigPath;
        if (config_path.len == 0) return error.NoConfigPath;
        const file = try std.fs.openFileAbsolute(config_path, .{ .mode = .read_only });
        defer file.close();

        const file_size = try file.getEndPos();
        if (file_size == 0) return;

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
        try writer.print("prompt={s}\n", .{self.prompt});
        try writer.print("log_dir={s}\n", .{self.log_dir orelse ""});
        try writer.print("show_cwd={s}\n", .{if (self.show_cwd) "true" else "false"});
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

        if (std.mem.eql(u8, key, "prompt")) {
            const new = try self.allocator.dupe(u8, value);
            self.allocator.free(self.prompt);
            self.prompt = new;
            return;
        }

        if (std.mem.eql(u8, key, "show_intro")) {
            self.show_intro = true;
            if (std.mem.eql(u8, value, "false")) self.show_intro = false;
            return;
        }

        if (std.mem.eql(u8, key, "show_cwd")) {
            self.show_cwd = true;
            if (std.mem.eql(u8, value, "false")) self.show_cwd = false;
            return;
        }
    }
};

const Fn = enum {
    Edit,
    Set,
    Source,
    Invalid,

    fn get(string: []const u8) Fn {
        if (std.mem.eql(u8, string, "edit") or std.mem.eql(u8, string, "-e")) return .Edit;
        if (std.mem.eql(u8, string, "set") or std.mem.eql(u8, string, "-s")) return .Set;
        if (std.mem.eql(u8, string, "source") or std.mem.eql(u8, string, "-sc")) return .Source;
        return .Invalid;
    }
};
