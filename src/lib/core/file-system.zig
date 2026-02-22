const std = @import("std");
const IO = @import("./io.zig").IO;
const Shell = @import("./shell.zig").Shell;
const Config = @import("./config.zig").Config;

pub const FileSystem = struct {
    io: *IO,
    config: *Config,

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

    pub fn init(io: *IO, config: *Config) FileSystem {
        return FileSystem{ .io = io, .config = config };
    }

    // Instances Methods
    pub fn controller(self: *FileSystem, args: []const u8) !void {
        if (args.len == 0) return try self.help();
        var arg_parts = std.mem.splitSequence(u8, args, " ");
        const func = Fn.get(arg_parts.first());
        const options = arg_parts.rest();
        switch (func) {
            .Copy => return try self.copy(options),
            .Delete => return try self.delete(options),
            .GetAbs => {
                const abs_path = try self.getAbs(options);
                return try self.io.print(abs_path, .Green);
            },
            .Help => return try self.help(),
            .Read => return try self.read(options),
            .Write => return try self.write(options),
            .Invalid => return try self.io.print("❌ Invalid func: Please use 'help' OR '-h' for help.\n\n", .Red),
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
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📂 From {s} ", .{self.config.prompt});
            try self.io.print(msg, .Green);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().readerStreaming(&buffer);
            if (try stdin_reader.interface.takeDelimiter('\n')) |line| from = line;
        }

        while (to.len == 0) {
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📂 To {s} ", .{self.config.prompt});
            try self.io.print(msg, .Green);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().readerStreaming(&buffer);
            if (try stdin_reader.interface.takeDelimiter('\n')) |line| to = line;
        }

        const file_type = FileType.get(from);
        if (file_type == .Invalid) return try self.io.print("❌ Invalid File Type.\n\n", .Red);

        const abs_to_path: []const u8 = try getAbsPath(to);
        const abs_from_path: []const u8 = try getAbsPath(from);
        _ = std.fs.copyFileAbsolute(abs_from_path, abs_to_path, .{}) catch {
            return try self.io.print("❌ File not found.\n\n", .Red);
        };

        const msg = try std.fmt.allocPrint(
            std.heap.page_allocator,
            "📋 File copied:\n   📄 from: {s}\n   📄 to: {s}\n\n",
            .{ abs_from_path, abs_to_path },
        );
        defer std.heap.page_allocator.free(msg);
        try self.io.print(msg, .Green);
    }

    pub fn deinit(self: *FileSystem) void {
        _ = self; // Placeholder to avoid unused parameter warning
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
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📝 Path {s} ", .{self.config.prompt});
            try self.io.print(msg, .Green);
            path = try self.io.readLine();
        }

        const file_type = FileType.get(path);
        if (file_type == .Invalid) return try self.io.print("❌ Invalid File Type.\n\n", .Red);

        const abs_path: []const u8 = try getAbsPath(path);
        _ = std.fs.deleteFileAbsolute(abs_path) catch {
            return try self.io.print("❌ File not found at path.\n\n", .Red);
        };
        const msg = try std.fmt.allocPrint(std.heap.page_allocator, "🗑️  File Deleted: {s}\n\n", .{abs_path});
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
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📝 Path {s} ", .{self.config.prompt});
            try self.io.print(msg, .Green);
            path = try self.io.readLine();
        }

        const abs_path: []const u8 = try getAbsPath(path);
        return abs_path;
    }

    fn help(self: *FileSystem) !void {
        try Shell.clear();
        const content = try self.readFile("./docs/file_system_help.txt");
        try self.io.print(content, .Green);
        try self.io.print("\n\n", .White);
    }

    fn read(self: *FileSystem, args: []const u8) !void {
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
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📂 Path {s} ", .{self.config.prompt});
            try self.io.print(msg, .Green);
            path = try self.io.readLine();
        }

        const content = try self.readFile(path);
        try self.io.print(content, .Magenta);
        try self.io.print("\n\n", .Magenta);
    }

    pub fn readFile(self: *FileSystem, path: []const u8) ![]const u8 {
        const file_type = FileType.get(path);
        if (file_type == .Invalid) {
            self.io.print("❌ Invalid File Type.\n\n", .Red) catch {};
            return "";
        }

        const abs_path: []const u8 = try getAbsPath(path);
        var file = std.fs.openFileAbsolute(abs_path, .{ .mode = .read_only }) catch {
            self.io.print("❌ File not found at path.\n\n", .Red) catch {};
            return "";
        };
        defer file.close();

        const file_size = try file.getEndPos();
        if (file_size == 0) return "";
        if (file_size > 10 * 1024 * 1024) {
            self.io.print("❌ File is too large to read (limit: 10MB).\n\n", .Red) catch {};
            return "";
        }

        const allocator = std.heap.page_allocator;
        const buffer = allocator.alloc(u8, file_size) catch {
            self.io.print("❌ Failed to allocate buffer for file content.\n\n", .Red) catch {};
            return "";
        };
        const file_bytes = try file.readAll(buffer);
        if (file_bytes != file_size) {
            self.io.print("❌ Failed to read entire file content.\n\n", .Red) catch {};
            allocator.free(buffer);
            return "";
        }
        return buffer[0..file_size];
    }

    fn write(self: *FileSystem, args: []const u8) !void {
        var path: []const u8 = "";
        var editor = Editor.get(self.config.editor);
        var arg_parts = std.mem.splitSequence(u8, args, " ");

        while (arg_parts.next()) |part| {
            if (std.mem.eql(u8, part, "") or part.len == 1) break;
            if (std.mem.eql(u8, part[0..2], "--")) {
                var key_value = std.mem.splitSequence(u8, part, "=");
                const key = key_value.first();
                const value = key_value.rest();
                if (std.mem.eql(u8, key, "--path") or std.mem.eql(u8, key, "--p")) path = value;
                if (std.mem.eql(u8, key, "--editor") or std.mem.eql(u8, key, "--e")) editor = Editor.get(value);
            } else continue;
        }

        while (path.len == 0) {
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📝 Path {s} ", .{self.config.prompt});
            try self.io.print(msg, .Green);
            path = try self.io.readLine();
        }

        while (editor == .Invalid) {
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📝 Editor (vim) {s} ", .{self.config.prompt});
            try self.io.print(msg, .Green);
            const _editor = try self.io.readLine();
            if (_editor.len == 0) editor = .Vim;
            editor = Editor.get(_editor);
        }

        const file_type = FileType.get(path);
        if (file_type == .Invalid) return self.io.print("❌ Invalid File Type.\n\n", .Red);
        const abs_path: []const u8 = try getAbsPath(path);
        try Shell.openEditor(editor, abs_path);
    }
};

pub const Editor = enum {
    Nano,
    Nvim,
    Vim,
    VsCode,
    Invalid,

    pub fn get(string: []const u8) Editor {
        if (std.mem.eql(u8, string, "nano")) return .Nano;
        if (std.mem.eql(u8, string, "nvim")) return .Nvim;
        if (std.mem.eql(u8, string, "vim") or string.len == 0) return .Vim;
        if (std.mem.eql(u8, string, "vscode") or std.mem.eql(u8, string, "code")) return .VsCode;
        return .Invalid;
    }
};

const FileType = enum {
    JS,
    JSON,
    MD,
    TS,
    Txt,
    Z,
    Invalid,

    fn get(path: []const u8) FileType {
        if (path.len == 0) return .Invalid;

        var path_parts = std.mem.splitSequence(u8, path, "/");
        var file_name: []const u8 = undefined;
        while (path_parts.next()) |part| file_name = part;

        var file_name_parts = std.mem.splitSequence(u8, file_name, ".");
        var file_type: []const u8 = "";
        while (file_name_parts.next()) |part| file_type = part;

        if (std.mem.eql(u8, file_type, "js")) return .JS;
        if (std.mem.eql(u8, file_type, "json")) return .JSON;
        if (std.mem.eql(u8, file_type, "md")) return .MD;
        if (std.mem.eql(u8, file_type, "ts")) return .TS;
        if (std.mem.eql(u8, file_type, "txt")) return .Txt;
        if (std.mem.eql(u8, file_type, "z")) return .Z;
        return .Invalid;
    }
};

const Fn = enum {
    Copy,
    Delete,
    GetAbs,
    Help,
    Read,
    Write,
    Invalid,

    fn get(string: []const u8) Fn {
        if (std.mem.eql(u8, string, "copy") or std.mem.eql(u8, string, "-cp")) return .Copy;
        if (std.mem.eql(u8, string, "delete") or std.mem.eql(u8, string, "-d")) return .Delete;
        if (std.mem.eql(u8, string, "get_abs") or std.mem.eql(u8, string, "-abs")) return .GetAbs;
        if (std.mem.eql(u8, string, "help") or std.mem.eql(u8, string, "-h")) return .Help;
        if (std.mem.eql(u8, string, "read") or std.mem.eql(u8, string, "-r")) return .Read;
        if (std.mem.eql(u8, string, "write") or std.mem.eql(u8, string, "-w")) return .Write;
        return .Invalid;
    }
};
