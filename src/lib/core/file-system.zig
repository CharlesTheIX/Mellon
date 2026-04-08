const std = @import("std");
const IO = @import("./io.zig").IO;
const Shell = @import("./shell.zig").Shell;
const Editor = @import("./utils.zig").Editor;
const Config = @import("./config.zig").Config;
const clear = @import("./utils.zig").clear;
const FileType = @import("./utils.zig").FileType;
const ErrorHandler = @import("./error-handler.zig").ErrorHandler;
const readFile = @import("./utils.zig").readFile;
const getAbsPath = @import("./utils.zig").getAbsPath;
const openEditor = @import("./utils.zig").openEditor;

pub const FileSystem = struct {
    io: *IO,
    config: *Config,
    Err: *ErrorHandler,

    pub fn init(io: *IO, config: *Config, Err: *ErrorHandler) FileSystem {
        return FileSystem{ .io = io, .config = config, .Err = Err };
    }

    pub fn controller(self: *FileSystem, args: []const u8) void {
        if (args.len == 0) return self.help() catch |err| {
            return self.Err.handle(err, "Failed to show file system help\n\n", false, true);
        };
        var arg_parts = std.mem.splitSequence(u8, args, " ");
        const func = Fn.get(arg_parts.first());
        const options = arg_parts.rest();
        switch (func) {
            .Copy => return self.copy(options) catch |err| return self.Err.handle(
                err,
                "Failed to copy file\n\n",
                false,
                true,
            ),
            .Delete => return self.delete(options) catch |err| return self.Err.handle(
                err,
                "Failed to delete file\n\n",
                false,
                true,
            ),
            .GetAbs => {
                const abs_path = self.getAbs(options) catch |err| {
                    return self.Err.handle(err, "Failed to get absolute path\n\n", false, true);
                };
                return self.io.print(abs_path, .Yellow);
            },
            .Help => return self.help() catch |err| return self.Err.handle(
                err,
                "Failed to show file system help\n\n",
                false,
                true,
            ),
            .Read => return self.read(options) catch |err| return self.Err.handle(
                err,
                "Failed to read file\n\n",
                false,
                true,
            ),
            .Write => return self.write(options) catch |err| return self.Err.handle(
                err,
                "Failed to write file\n\n",
                false,
                true,
            ),
            .Invalid => return self.io.print("❌ Invalid func: Please use 'help' OR '-h' for help.\n\n", .Red),
        }
    }

    // Methods
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
                if (std.mem.eql(u8, key, "--from")) from = value;
                if (std.mem.eql(u8, key, "--to")) to = value;
            } else continue;
        }
        while (from.len == 0) {
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📂 From {s} ", .{self.config.prompt.symbol});
            self.io.print(msg, .Yellow);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().readerStreaming(&buffer);
            const line = try stdin_reader.interface.takeDelimiter('\n') orelse "";
            from = line;
        }
        while (to.len == 0) {
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📂 To {s} ", .{self.config.prompt.symbol});
            self.io.print(msg, .Yellow);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().readerStreaming(&buffer);
            const line = try stdin_reader.interface.takeDelimiter('\n') orelse "";
            to = line;
        }
        const file_type = FileType.get(from);
        if (file_type == .Invalid) return self.io.print("❌ Invalid File Type.\n\n", .Red);
        const abs_to_path: []const u8 = try getAbsPath(to);
        const abs_from_path: []const u8 = try getAbsPath(from);
        _ = try std.fs.copyFileAbsolute(abs_from_path, abs_to_path, .{});
        const msg = try std.fmt.allocPrint(
            std.heap.page_allocator,
            "📋 File copied:\n   📄 from: {s}\n   📄 to: {s}\n\n",
            .{ abs_from_path, abs_to_path },
        );
        defer std.heap.page_allocator.free(msg);
        self.io.print(msg, .Yellow);
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
                if (std.mem.eql(u8, key, "--path")) path = value;
            } else continue;
        }
        while (path.len == 0) {
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📝 Path {s} ", .{self.config.prompt.symbol});
            self.io.print(msg, .Yellow);
            path = self.io.readLine();
        }
        const file_type = FileType.get(path);
        if (file_type == .Invalid) return self.io.print("❌ Invalid File Type.\n\n", .Red);
        const abs_path: []const u8 = try getAbsPath(path);
        _ = try std.fs.deleteFileAbsolute(abs_path);
        const msg = try std.fmt.allocPrint(std.heap.page_allocator, "🗑️  File Deleted: {s}\n\n", .{abs_path});
        defer std.heap.page_allocator.free(msg);
        self.io.print(msg, .Yellow);
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
                if (std.mem.eql(u8, key, "--path")) path = value;
            } else continue;
        }
        while (path.len == 0) {
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📝 Path {s} ", .{self.config.prompt.symbol});
            self.io.print(msg, .Yellow);
            path = self.io.readLine();
        }
        const abs_path: []const u8 = try getAbsPath(path);
        return abs_path;
    }

    fn help(self: *FileSystem) !void {
        openEditor(Editor.get(self.config.editor), "./docs/core/file-system.md");
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
                if (std.mem.eql(u8, key, "--path")) path = value;
            } else continue;
        }
        while (path.len == 0) {
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📂 Path {s} ", .{self.config.prompt.symbol});
            self.io.print(msg, .Yellow);
            path = self.io.readLine();
        }
        const content = try readFile(path);
        self.io.print(content, .Magenta);
        self.io.print("\n\n", .Magenta);
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
                if (std.mem.eql(u8, key, "--path")) path = value;
                if (std.mem.eql(u8, key, "--editor")) editor = Editor.get(value);
            } else continue;
        }
        while (path.len == 0) {
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📝 Path {s} ", .{self.config.prompt.symbol});
            self.io.print(msg, .Yellow);
            path = self.io.readLine();
        }
        while (editor == .Invalid) {
            const msg = try std.fmt.allocPrint(std.heap.page_allocator, "📝 Editor (vim) {s} ", .{self.config.prompt.symbol});
            self.io.print(msg, .Yellow);
            const _editor = self.io.readLine();
            if (_editor.len == 0) editor = .Vim;
            editor = Editor.get(_editor);
        }
        const file_type = FileType.get(path);
        if (file_type == .Invalid) return self.io.print("❌ Invalid File Type.\n\n", .Red);
        const abs_path: []const u8 = try getAbsPath(path);
        openEditor(editor, abs_path);
    }
};

const Fn = enum {
    Copy,
    Help,
    Read,
    Write,
    Delete,
    GetAbs,
    Invalid,

    fn get(string: []const u8) Fn {
        if (std.mem.eql(u8, string, "copy")) return .Copy;
        if (std.mem.eql(u8, string, "read")) return .Read;
        if (std.mem.eql(u8, string, "write")) return .Write;
        if (std.mem.eql(u8, string, "delete")) return .Delete;
        if (std.mem.eql(u8, string, "get_abs")) return .GetAbs;
        if (std.mem.eql(u8, string, "help") or std.mem.eql(u8, string, "-h")) return .Help;
        return .Invalid;
    }
};
