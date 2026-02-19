const std = @import("std");
// const sc = @import("../shell-commands.zig");

pub const Editor = enum { Invalid, Nvim, VsCode };
const FileType = enum { Txt, MD, JSON, Invalid };
const Function = enum { Help, Read, Write, Update, Delete, Copy, Invalid };

pub const FileSystem = struct {
    writer: *std.fs.File.Writer,

    pub fn controller(self: *FileSystem, args: []const u8) !void {
        if (args.len == 0) {
            try self.writer.interface.print("❌ FUNCTION Required: Please use '-help' OR '-h' for HELP with this COMMAND.\n", .{});
            try self.writer.interface.flush();
            return;
        }

        var arg_parts = std.mem.splitSequence(u8, args, " ");
        const function = stringToFunction(arg_parts.first());
        const options = arg_parts.rest();
        switch (function) {
            .Help => return try self.help(),
            .Read => return try self.read(options),
            .Copy => return try self.copy(options),
            .Write => return try self.write(options),
            .Update => return try self.update(options),
            .Delete => return try self.delete(options),
            .Invalid => {
                try self.writer.interface.print("❌ FUNCTION Required: Please use '-help' OR '-h' for HELP with this COMMAND.\n", .{});
                try self.writer.interface.flush();
                return;
            },
        }
    }

    fn copy(self: *FileSystem, args: []const u8) !void {
        var to: []const u8 = "";
        var from: []const u8 = "";
        var arg_parts = std.mem.splitSequence(u8, args, " ");

        while (arg_parts.next()) |part| {
            if (std.mem.eql(u8, part, "")) break;
            if (std.mem.eql(u8, part[0..2], "--")) {
                var key_value = std.mem.splitSequence(u8, part, "=");
                const key = key_value.first();
                const value = key_value.rest();
                if (std.mem.eql(u8, key, "--from") or std.mem.eql(u8, key, "--f")) from = value;
                if (std.mem.eql(u8, key, "--to") or std.mem.eql(u8, key, "--t")) to = value;
            } else continue;
        }

        while (from.len == 0) {
            var buffer: [1024]u8 = undefined;
            try self.writer.interface.print("\x1b[32mFrom ⚡\x1b[0m ", .{});
            try self.writer.interface.flush();
            var stdin_reader = std.fs.File.stdin().reader(&buffer);
            if (try stdin_reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| from = line;
        }

        while (to.len == 0) {
            var buffer: [1024]u8 = undefined;
            try self.writer.interface.print("\x1b[32mTo ⚡\x1b[0m ", .{});
            try self.writer.interface.flush();
            var stdin_reader = std.fs.File.stdin().reader(&buffer);
            if (try stdin_reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| to = line;
        }

        const file_type = stringToFileType(from);
        if (file_type == .Invalid) {
            try self.writer.interface.print("❌ Invalid File Type.\n", .{});
            try self.writer.interface.flush();
            return;
        }
        const abs_to_path: []const u8 = try getAbsPath(to);
        const abs_from_path: []const u8 = try getAbsPath(from);
        _ = std.fs.copyFileAbsolute(abs_from_path, abs_to_path, .{}) catch {
            try self.writer.interface.print("❌ File not found: {s}\n", .{abs_from_path});
            try self.writer.interface.flush();
            return;
        };
        try self.writer.interface.print("📋 File copied:\n   📄 from: {s}\n   📄 to: {s}\n", .{ abs_from_path, abs_to_path });
        try self.writer.interface.flush();
    }

    pub fn deinit(self: *FileSystem) void {
        // No resources to clean up for now
        _ = self;
    }

    fn delete(self: *FileSystem, args: []const u8) !void {
        var path: []const u8 = "";
        var arg_parts = std.mem.splitSequence(u8, args, " ");

        while (arg_parts.next()) |part| {
            if (std.mem.eql(u8, part, "")) break;
            if (std.mem.eql(u8, part[0..2], "--")) {
                var key_value = std.mem.splitSequence(u8, part, "=");
                const key = key_value.first();
                const value = key_value.rest();
                if (std.mem.eql(u8, key, "--path") or std.mem.eql(u8, key, "--p")) path = value;
            } else continue;
        }

        while (path.len == 0) {
            var buffer: [1024]u8 = undefined;
            try self.writer.interface.print("\x1b[32mPath ⚡\x1b[0m ", .{});
            try self.writer.interface.flush();
            var stdin_reader = std.fs.File.stdin().reader(&buffer);
            if (try stdin_reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| path = line;
        }

        const file_type = stringToFileType(path);
        if (file_type == .Invalid) {
            try self.writer.interface.print("❌ Invalid File Type.\n", .{});
            try self.writer.interface.flush();
            return;
        }

        const abs_path: []const u8 = try getAbsPath(path);
        _ = std.fs.deleteFileAbsolute(abs_path) catch {
            try self.writer.interface.print("❌ File not found: {s}\n", .{abs_path});
            try self.writer.interface.flush();
            return;
        };
        try self.writer.interface.print("🗑️  File Deleted: {s}\n", .{abs_path});
        try self.writer.interface.flush();
    }

    fn help(self: *FileSystem) !void {
        _ = self;
        // try sc.clearBuffer();
        // try read("--path=./src/inc/help.file.md");
    }

    pub fn init(writer: *std.fs.File.Writer) FileSystem {
        return FileSystem{ .writer = writer };
    }

    pub fn read(self: *FileSystem, args: []const u8) !void {
        var path: []const u8 = "";
        var arg_parts = std.mem.splitSequence(u8, args, " ");

        while (arg_parts.next()) |part| {
            if (std.mem.eql(u8, part, "")) break;
            if (std.mem.eql(u8, part[0..2], "--")) {
                var key_value = std.mem.splitSequence(u8, part, "=");
                const key = key_value.first();
                const value = key_value.rest();
                if (std.mem.eql(u8, key, "--path") or std.mem.eql(u8, key, "--p")) path = value;
            } else continue;
        }

        while (path.len == 0) {
            var buffer: [1024]u8 = undefined;
            try self.writer.interface.print("\x1b[32mPath ⚡\x1b[0m ", .{});
            try self.writer.interface.flush();
            const stdin_file = std.fs.File.stdin();
            const bytes_read = try stdin_file.readAll(&buffer);
            if (bytes_read > 0 and buffer[bytes_read - 1] == '\n') path = std.mem.trim(u8, buffer[0..bytes_read], "\n");
        }

        const file_type = stringToFileType(path);
        if (file_type == .Invalid) {
            try self.writer.interface.print("❌ Invalid File Type.\n", .{});
            try self.writer.interface.flush();
            return;
        }

        const abs_path: []const u8 = try getAbsPath(path);
        var file = std.fs.openFileAbsolute(abs_path, .{ .mode = .read_only }) catch {
            try self.writer.interface.print("❌ File not found: {s}\n", .{abs_path});
            try self.writer.interface.flush();
            return;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        const allocator = std.heap.page_allocator;
        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);

        const file_bytes = try file.readAll(buffer);
        std.debug.assert(file_bytes == file_size);

        // try sc.clearBuffer();
        try self.writer.interface.print("{s}\n", .{buffer});
        try self.writer.interface.flush();
    }

    fn update(self: *FileSystem, args: []const u8) !void {
        var arg_parts = std.mem.splitSequence(u8, args, " ");
        var path: []const u8 = "";
        var editor = Editor.Invalid;

        while (arg_parts.next()) |part| {
            if (std.mem.eql(u8, part, "")) break;
            if (std.mem.eql(u8, part[0..2], "--")) {
                var key_value = std.mem.splitSequence(u8, part, "=");
                const key = key_value.first();
                const value = key_value.rest();
                if (std.mem.eql(u8, key, "--path") or std.mem.eql(u8, key, "--p")) path = value;
                if (std.mem.eql(u8, key, "--editor") or std.mem.eql(u8, key, "--e")) editor = stringToEditor(value);
            } else continue;
        }

        while (path.len == 0) {
            var buffer: [1024]u8 = undefined;
            try self.writer.interface.print("\x1b[32mPath ⚡\x1b[0m ", .{});
            try self.writer.interface.flush();
            var stdin_reader = std.fs.File.stdin().reader(&buffer);
            if (try stdin_reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| path = line;
        }

        while (editor == .Invalid) {
            var buffer: [1024]u8 = undefined;
            try self.writer.interface.print("\x1b[32mEditor (nvim) ⚡\x1b[0m ", .{});
            try self.writer.interface.flush();
            var stdin_reader = std.fs.File.stdin().reader(&buffer);
            if (try stdin_reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
                if (line.len == 0) editor = .Nvim;
            }
        }

        const file_type = stringToFileType(path);
        if (file_type == .Invalid) {
            try self.writer.interface.print("❌ Invalid File Type.\n", .{});
            try self.writer.interface.flush();
            return;
        }
        const abs_path: []const u8 = try getAbsPath(path);
        _ = abs_path;
        // try sc.openEditor(editor, abs_path);
    }

    fn write(self: *FileSystem, args: []const u8) !void {
        var path: []const u8 = "";
        var editor = Editor.Invalid;
        var arg_parts = std.mem.splitSequence(u8, args, " ");

        while (arg_parts.next()) |part| {
            if (std.mem.eql(u8, part, "") or part.len == 1) break;
            if (std.mem.eql(u8, part[0..2], "--")) {
                var key_value = std.mem.splitSequence(u8, part, "=");
                const key = key_value.first();
                const value = key_value.rest();
                if (std.mem.eql(u8, key, "--path") or std.mem.eql(u8, key, "--p")) path = value;
                if (std.mem.eql(u8, key, "--editor") or std.mem.eql(u8, key, "--e")) editor = stringToEditor(value);
            } else continue;
        }

        while (path.len == 0) {
            var buffer: [1024]u8 = undefined;
            try self.writer.interface.print("\x1b[32mPath ⚡\x1b[0m ", .{});
            try self.writer.interface.flush();
            var stdin_reader = std.fs.File.stdin().reader(&buffer);
            if (try stdin_reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
                path = line;
            }
        }

        while (editor == .Invalid) {
            var buffer: [1024]u8 = undefined;
            try self.writer.interface.print("\x1b[32mEditor (nvim) ⚡\x1b[0m ", .{});
            try self.writer.interface.flush();
            var stdin_reader = std.fs.File.stdin().reader(&buffer);
            if (try stdin_reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
                if (line.len == 0) editor = .Nvim;
            }
        }

        const file_type = stringToFileType(path);
        if (file_type == .Invalid) {
            try self.writer.interface.print("❌ Invalid File Type\n", .{});
            try self.writer.interface.flush();
            return;
        }
        const abs_path: []const u8 = try getAbsPath(path);
        _ = abs_path;
        // try sc.openEditor(editor, abs_path);
    }
};

fn getAbsPath(path: []const u8) ![]const u8 {
    const path_first_char = path[0..1];

    if (std.mem.eql(u8, path_first_char, "/")) return path;

    const allocator = std.heap.page_allocator;

    if (std.mem.eql(u8, path_first_char, "~")) {
        const env = try std.process.getEnvMap(allocator);
        const home_path = env.get("HOME") orelse "";
        return try std.fs.path.join(allocator, &[_][]const u8{ home_path, "/", path[1..] });
    }

    var count: u8 = 0;
    var cwd_path: []const u8 = "";
    var path_parts = std.mem.splitSequence(u8, path, "/");

    while (path_parts.next()) |part| {
        if (std.mem.eql(u8, part, ".")) {
            count += 2;
            cwd_path = try std.fs.path.join(allocator, &[_][]const u8{ cwd_path, "." });
        } else if (std.mem.eql(u8, part, "..")) {
            if (count == 0) cwd_path = try std.fs.path.join(allocator, &[_][]const u8{ cwd_path, ".." });
            if (count >= 2) cwd_path = try std.fs.path.join(allocator, &[_][]const u8{ cwd_path, "/.." });
            count += 3;
        } else break;
    }

    const cwd = try std.fs.cwd().realpathAlloc(allocator, cwd_path);
    defer allocator.free(cwd);
    return try std.fs.path.join(allocator, &[_][]const u8{ cwd, "/", path[count..] });
}

fn stringToEditor(string: []const u8) Editor {
    _ = string;
    return .Nvim;
}

fn stringToFileType(string: []const u8) FileType {
    if (string.len == 0) return .Invalid;

    var path_parts = std.mem.splitSequence(u8, string, "/");
    var file_name: []const u8 = undefined;

    while (path_parts.next()) |part| file_name = part;

    var file_name_parts = std.mem.splitSequence(u8, file_name, ".");
    var file_type: []const u8 = "";

    while (file_name_parts.next()) |part| file_type = part;

    if (std.mem.eql(u8, file_type, "md")) return .MD;
    if (std.mem.eql(u8, file_type, "txt")) return .Txt;
    if (std.mem.eql(u8, file_type, "json")) return .JSON;
    return .Invalid;
}

fn stringToFunction(string: []const u8) Function {
    if (std.mem.eql(u8, string, "copy")) return .Copy;
    if (std.mem.eql(u8, string, "delete")) return .Delete;
    if (std.mem.eql(u8, string, "help") or std.mem.eql(u8, string, "-h")) return .Help;
    if (std.mem.eql(u8, string, "read")) return .Read;
    if (std.mem.eql(u8, string, "update")) return .Update;
    if (std.mem.eql(u8, string, "write")) return .Write;
    return .Invalid;
}
