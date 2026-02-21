const std = @import("std");
const IO = @import("./io.zig").IO;
const Editor = @import("./file-system.zig").Editor;

pub const Shell = struct {
    io: *IO,

    // Static Methods
    pub fn init(io: *IO) Shell {
        return Shell{ .io = io };
    }

    pub fn clear() !void {
        const allocator = std.heap.page_allocator;
        const args_array = &[1][]const u8{"clear"};
        var child_process = std.process.Child.init(args_array, allocator);
        _ = try child_process.spawnAndWait();
    }

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

            const stat = bin_file.stat() catch continue;
            const is_exe_file = stat.mode & 0b001 != 0;

            if (is_exe_file) {
                return_value = try allocator.dupe(u8, full_path);
                break;
            }
        }

        return return_value;
    }

    pub fn openEditor(editor: Editor, path: []const u8) !void {
        var args_array = &[2][]const u8{ "vim", path };
        switch (editor) {
            .Nvim => args_array = &[2][]const u8{ "nvim", path },
            .VsCode => args_array = &[2][]const u8{ "code", path },
            else => {},
        }
        const allocator = std.heap.page_allocator;
        var child_process = std.process.Child.init(args_array, allocator);
        _ = try child_process.spawnAndWait();
    }

    fn pwd() !void {
        const allocator = std.heap.page_allocator;
        const args_array = &[2][]const u8{ "pwd", "-L" };
        var child_process = std.process.Child.init(args_array, allocator);
        _ = try child_process.spawnAndWait();
    }

    // Instance Methods
    pub fn controller(self: *Shell, command: []const u8, args: []const u8) !void {
        const path = try getCommandIsInPATH(command);
        if (std.mem.eql(u8, path, "")) return self.io.print("❌ Shell Command Not Found\n", .Red);

        if (std.mem.eql(u8, command, "pwd")) return try pwd();
        if (std.mem.eql(u8, command, "clear")) return try clear();

        var count: u8 = 1;
        var arg_parts = std.mem.splitSequence(u8, args, " ");
        while (arg_parts.next()) |part| {
            _ = part;
            count += 1;
        }

        const allocator = std.heap.page_allocator;
        const args_array = try allocator.alloc([]const u8, count);
        defer allocator.free(args_array);

        count = 1;
        arg_parts.reset();
        args_array[0] = command;
        while (arg_parts.next()) |part| {
            args_array[count] = part;
            count += 1;
        }

        var child_process = std.process.Child.init(args_array, allocator);
        _ = try child_process.spawnAndWait();
    }

    pub fn deinit(self: *Shell) void {
        _ = self; // Placeholder to avoid unused parameter warning
    }
};
