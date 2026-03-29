const std = @import("std");
const IO = @import("./io.zig").IO;
const Editor = @import("./file-system.zig").Editor;
const ErrorHandler = @import("./error-handler.zig").ErrorHandler;

fn getCommandIsInPATH(command: []const u8) ![]const u8 {
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

fn pwd() !void {
    const allocator = std.heap.page_allocator;
    const args_array = &[2][]const u8{ "pwd", "-L" };
    var child_process = std.process.Child.init(args_array, allocator);
    _ = try child_process.spawnAndWait();
}

pub fn clear() void {
    const allocator = std.heap.page_allocator;
    const args_array = &[1][]const u8{"clear"};
    var child_process = std.process.Child.init(args_array, allocator);
    _ = child_process.spawnAndWait() catch {
        std.debug.print("❌ Failed to clear the screen. Make sure 'clear' is available in your PATH.\n\n", .{});
    };
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

pub const Shell = struct {
    io: *IO,
    Err: *ErrorHandler,

    pub fn init(io: *IO, Err: *ErrorHandler) Shell {
        return Shell{ .io = io, .Err = Err };
    }

    // Instance Methods
    pub fn controller(self: *Shell, command: []const u8, args: []const u8) void {
        const path = getCommandIsInPATH(command) catch |err| {
            return self.Err.handle(err, "Failed to check if command is in PATH\n\n", false, true);
        };
        if (std.mem.eql(u8, path, "")) return self.io.print("❌ Shell Command Not Found\n\n", .Red);
        if (std.mem.eql(u8, command, "clear")) return clear();
        if (std.mem.eql(u8, command, "pwd")) return pwd() catch |err| {
            return self.Err.handle(err, "Failed to execute pwd command\n\n", false, true);
        };
        var count: u8 = 1;
        var arg_parts = std.mem.splitSequence(u8, args, " ");
        while (arg_parts.next()) |part| {
            _ = part;
            count += 1;
        }
        const allocator = std.heap.page_allocator;
        const args_array = allocator.alloc([]const u8, count) catch |err| {
            return self.Err.handle(err, "Failed to allocate memory for command arguments\n\n", false, true);
        };
        defer allocator.free(args_array);
        count = 1;
        arg_parts.reset();
        args_array[0] = command;
        while (arg_parts.next()) |part| {
            args_array[count] = part;
            count += 1;
        }
        var child_process = std.process.Child.init(args_array, allocator);
        _ = child_process.spawnAndWait() catch |err| {
            return self.Err.handle(err, "Failed to execute shell command\n\n", false, true);
        };
    }
};
