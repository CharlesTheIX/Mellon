const std = @import("std");
const Shell = @import("./shell.zig").Shell;
const Editor = @import("./file-system.zig").Editor;

pub const Config = struct {
    show_cwd: bool,
    show_intro: bool,
    editor: []const u8,
    prompt: []const u8,
    log_dir: []const u8,
    config_path: []const u8,
    allocator: std.mem.Allocator,

    // Static Methods
    pub fn init(allocator: std.mem.Allocator) Config {
        const home = std.posix.getenv("HOME") orelse "~";
        const log_dir = std.fmt.allocPrint(allocator, "{s}/.mellon_logs", .{home}) catch "";
        const config_path = std.fmt.allocPrint(allocator, "{s}/.mellonrc", .{home}) catch "";
        const default_editor = allocator.dupe(u8, "vim") catch "vim";
        const default_prompt = allocator.dupe(u8, "⚡") catch "⚡";
        var config = Config{
            .show_cwd = true,
            .show_intro = true,
            .log_dir = log_dir,
            .allocator = allocator,
            .editor = default_editor,
            .prompt = default_prompt,
            .config_path = config_path,
        };
        config.load() catch {};
        return config;
    }

    // Instances Methods
    pub fn controller(self: *Config, args: []const u8) !void {
        if (args.len == 0) return try self.edit();
        var arg_parts = std.mem.splitSequence(u8, args, " ");
        const func = Fn.get(arg_parts.first());
        switch (func) {
            .Set => {
                while (arg_parts.next()) |pair| {
                    var kv = std.mem.splitScalar(u8, pair, '=');
                    const key = kv.first();
                    const value = kv.rest();
                    if (key.len == 0 or value.len == 0) continue;
                    try self.set(key, value);
                }
                return self.save() catch {};
            },
            .Source => return try self.load(),
            else => return try self.edit(),
        }
    }

    pub fn deinit(self: *Config) void {
        self.allocator.free(self.editor);
        self.allocator.free(self.prompt);
        if (self.config_path.len > 0) self.allocator.free(self.config_path);
    }

    fn edit(self: *Config) !void {
        if (self.config_path.len == 0) return error.NoConfigPath;
        const editor = Editor.get(self.editor);
        try Shell.openEditor(editor, self.config_path);
        try self.load();
    }

    pub fn getFullPrompt(self: *const Config) ![]const u8 {
        if (self.show_cwd) {
            const cwd = try std.fs.cwd().realpathAlloc(self.allocator, ".");
            defer self.allocator.free(cwd);
            return try std.fmt.allocPrint(self.allocator, "{s} {s} ", .{ cwd, self.prompt });
        }
        return try std.fmt.allocPrint(self.allocator, "{s} ", .{self.prompt});
    }

    fn load(self: *Config) !void {
        if (self.config_path.len == 0) return;
        const file = std.fs.openFileAbsolute(self.config_path, .{ .mode = .read_only }) catch |err| {
            if (err == error.FileNotFound) return self.save();
            return err;
        };
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
        if (self.config_path.len == 0) return error.NoConfigPath;
        const file = try std.fs.createFileAbsolute(self.config_path, .{});
        defer file.close();

        var buffer: [2048]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buffer);
        const writer = stream.writer();

        try writer.print("# Mellon Configuration File\n", .{});
        try writer.print("editor={s}\n", .{self.editor});
        try writer.print("prompt={s}\n", .{self.prompt});
        try writer.print("log_dir={s}\n", .{self.log_dir});
        try writer.print("show_cwd={s}\n", .{if (self.show_cwd) "true" else "false"});
        try writer.print("show_intro={s}\n", .{if (self.show_intro) "true" else "false"});
        try file.writeAll(stream.getWritten());
    }

    fn set(self: *Config, key: []const u8, value: []const u8) !void {
        if (value.len == 0) return;

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
