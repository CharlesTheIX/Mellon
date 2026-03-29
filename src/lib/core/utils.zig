const std = @import("std");

// Functions
pub fn clear() void {
    const allocator = std.heap.page_allocator;
    const args_array = &[1][]const u8{"clear"};
    var child_process = std.process.Child.init(args_array, allocator);
    _ = child_process.spawnAndWait() catch {
        std.debug.print("❌ Failed to clear the screen. Make sure 'clear' is available in your PATH.\n\n", .{});
    };
}

pub fn getAbsPath(path: []const u8) ![]const u8 {
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

pub fn getCommandIsInPATH(command: []const u8) ![]const u8 {
    var return_value: []const u8 = "";
    const allocator = std.heap.page_allocator;
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();
    const path = env.get("PATH") orelse "";
    var path_dirs = std.mem.splitSequence(u8, path, ":");
    while (path_dirs.next()) |dir| {
        if (dir.len == 0) continue;
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir, command });
        defer allocator.free(full_path);
        // Some paths in my PATH are not abs, this line skips those non-abs paths
        if (full_path.len == 0 or full_path[0] != '/') continue;
        const bin_file = std.fs.openFileAbsolute(full_path, .{ .mode = .read_only }) catch continue;
        defer bin_file.close();
        const stat = try bin_file.stat();
        const is_exe_file = stat.mode & 0b001 != 0;
        if (is_exe_file) {
            return_value = try allocator.dupe(u8, full_path);
            break;
        }
    }
    return return_value;
}

pub fn openEditor(editor: Editor, path: []const u8) void {
    var args_array = &[2][]const u8{ "vim", path };
    switch (editor) {
        .Nvim => args_array = &[2][]const u8{ "nvim", path },
        .VsCode => args_array = &[2][]const u8{ "code", path },
        else => {},
    }
    const allocator = std.heap.page_allocator;
    var child_process = std.process.Child.init(args_array, allocator);
    _ = child_process.spawnAndWait() catch {
        std.debug.print("❌ Failed to open editor. Make sure it's installed and in your PATH.\n\n", .{});
    };
}

pub fn pwd() !void {
    const allocator = std.heap.page_allocator;
    const args_array = &[2][]const u8{ "pwd", "-L" };
    var child_process = std.process.Child.init(args_array, allocator);
    _ = try child_process.spawnAndWait();
}

pub fn readFile(path: []const u8) ![]const u8 {
    const file_type = FileType.get(path);
    if (file_type == .Invalid) return error.InvalidFileType;
    const abs_path: []const u8 = try getAbsPath(path);
    var file = try std.fs.openFileAbsolute(abs_path, .{ .mode = .read_only });
    defer file.close();
    const file_size = try file.getEndPos();
    if (file_size == 0) return "";
    if (file_size > 10 * 1024 * 1024) return error.FileTooLarge;
    const allocator = std.heap.page_allocator;
    const buffer = try allocator.alloc(u8, file_size);
    const file_bytes = try file.readAll(buffer);
    if (file_bytes != file_size) {
        allocator.free(buffer);
        return error.IncompleteRead;
    }
    return buffer[0..file_size];
}

// Enums
pub const Clr = enum {
    Blue,
    Cyan,
    Green,
    Magenta,
    Red,
    White,
    Yellow,
    Reset,

    pub fn code(self: Clr) []const u8 {
        return switch (self) {
            .Blue => "\x1b[34m",
            .Cyan => "\x1b[36m",
            .Green => "\x1b[32m",
            .Magenta => "\x1b[35m",
            .Red => "\x1b[31m",
            .White => "\x1b[37m",
            .Yellow => "\x1b[33m",
            .Reset => "\x1b[0m",
        };
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

pub const FileType = enum {
    JS,
    JSON,
    MD,
    TS,
    Txt,
    Z,
    Invalid,

    pub fn get(path: []const u8) FileType {
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
