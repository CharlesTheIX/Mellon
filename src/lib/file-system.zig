const std = @import("std");
const IO = @import("./io.zig").IO;

pub const Editor = enum { Invalid, Nvim, VsCode };
const FileType = enum { Txt, MD, JSON, Invalid };
const Function = enum { Help, Read, Write, Update, Delete, Copy, GetAbs, Invalid };

fn stringToEditor(string: []const u8) Editor {
    if (std.mem.eql(u8, string, "nvim") or string.len == 0) return .Nvim;
    if (std.mem.eql(u8, string, "vscode") or std.mem.eql(u8, string, "code")) return .VsCode;
    return .Invalid;
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

pub const FileSystem = struct {
    io: IO,

    // Static Methods
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

    pub fn init(reader: *std.fs.File.Reader, writer: *std.fs.File.Writer) FileSystem {
        return FileSystem{ .io = IO.init(reader, writer) };
    }

    // Instances Methods
    pub fn controller(self: *FileSystem, args: []const u8) !void {
        if (args.len == 0) return self.io.print("❌ fn required: Please use '-help' OR '-h' for help.\n", .Red);

        var arg_parts = std.mem.splitSequence(u8, args, " ");
        const function = stringToFunction(arg_parts.first());
        const options = arg_parts.rest();
        switch (function) {
            .Copy => return try self.copy(options),
            .Delete => return try self.delete(options),
            .GetAbs => {
                const abs_path = try self.getAbs(options);
                return try self.io.print(abs_path, .Green);
            },
            .Help => return try self.help(),
            .Read => return try self.read(options),
            .Update => return try self.update(options),
            .Write => return try self.write(options),
            .Invalid => return try self.io.print("❌ Invalid fn: Please use 'help' OR '-h' for help.\n", .Red),
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
            try self.io.print("From ⚡ ", .Green);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().readerStreaming(&buffer);
            if (try stdin_reader.interface.takeDelimiter('\n')) |line| from = line;
        }

        while (to.len == 0) {
            try self.io.print("To ⚡ ", .Green);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().readerStreaming(&buffer);
            if (try stdin_reader.interface.takeDelimiter('\n')) |line| to = line;
        }

        const file_type = stringToFileType(from);
        if (file_type == .Invalid) return try self.io.print("❌ Invalid File Type.\n", .Red);

        const abs_to_path: []const u8 = try getAbsPath(to);
        const abs_from_path: []const u8 = try getAbsPath(from);
        _ = std.fs.copyFileAbsolute(abs_from_path, abs_to_path, .{}) catch {
            return try self.io.print("File not found.\n", .Red);
        };

        const msg = try std.fmt.allocPrint(
            std.heap.page_allocator,
            "📋 File copied:\n   📄 from: {s}\n   📄 to: {s}\n",
            .{ abs_from_path, abs_to_path },
        );
        defer std.heap.page_allocator.free(msg);
        try self.io.print(msg, .Green);
    }

    pub fn deinit(self: *FileSystem) !void {
        try self.io.deinit();
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
            try self.io.print("Path ⚡ ", .Green);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().reader(&buffer);
            if (try stdin_reader.interface.takeDelimiter('\n')) |line| path = line;
        }

        const file_type = stringToFileType(path);
        if (file_type == .Invalid) return try self.io.print("❌ Invalid File Type.\n", .Red);

        const abs_path: []const u8 = try getAbsPath(path);
        _ = std.fs.deleteFileAbsolute(abs_path) catch {
            return try self.io.print("❌ File not found at path.\n", .Red);
        };
        const msg = try std.fmt.allocPrint(std.heap.page_allocator, "🗑️  File Deleted: {s}\n", .{abs_path});
        defer std.heap.page_allocator.free(msg);
        try self.io.print(msg, .Green);
    }

    fn getAbs(self: *FileSystem, args: []const u8) ![]const u8 {
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
            try self.io.print("Path ⚡ ", .Green);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().reader(&buffer);
            if (try stdin_reader.interface.takeDelimiter('\n')) |line| path = line;
        }
        const abs_path: []const u8 = try getAbsPath(path);
        return abs_path;
    }

    fn help(self: *FileSystem) !void {
        _ = self;
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
            try self.io.print("Path ⚡ ", .Green);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().readerStreaming(&buffer);
            if (try stdin_reader.interface.takeDelimiter('\n')) |line| path = line;
        }

        const file_type = stringToFileType(path);
        if (file_type == .Invalid) return try self.io.print("❌ Invalid File Type.\n", .Red);

        const abs_path: []const u8 = try getAbsPath(path);
        var file = std.fs.openFileAbsolute(abs_path, .{ .mode = .read_only }) catch {
            return try self.io.print("❌ File not found at path.\n", .Red);
        };
        defer file.close();

        const file_size = try file.getEndPos();
        const allocator = std.heap.page_allocator;
        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);

        const file_bytes = try file.readAll(buffer);
        std.debug.assert(file_bytes == file_size);
        try self.io.print(buffer, .Magenta);
        try self.io.print("\n\n", .Magenta);
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
            try self.io.print("Path ⚡ ", .Green);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().reader(&buffer);
            if (try stdin_reader.interface.takeDelimiter('\n')) |line| path = line;
        }

        while (editor == .Invalid) {
            try self.io.print("Editor (nvim) ⚡ ", .Green);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().reader(&buffer);
            if (try stdin_reader.interface.takeDelimiter('\n')) |line| {
                if (line.len == 0) editor = .Nvim;
            }
        }

        const file_type = stringToFileType(path);
        if (file_type == .Invalid) return try self.io.print("❌ Invalid File Type.\n", .Red);
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
            try self.io.print("Path ⚡ ", .Green);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().reader(&buffer);
            if (try stdin_reader.interface.takeDelimiter('\n')) |line| path = line;
        }

        while (editor == .Invalid) {
            try self.io.print("Editor (nvim) ⚡ ", .Green);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().reader(&buffer);
            if (try stdin_reader.interface.takeDelimiter('\n')) |line| {
                if (line.len == 0) editor = .Nvim;
            }
        }

        const file_type = stringToFileType(path);
        if (file_type == .Invalid) return self.io.print("❌ Invalid File Type.\n", .Red);
        const abs_path: []const u8 = try getAbsPath(path);
        _ = abs_path;
        // try sc.openEditor(editor, abs_path);
    }
};
