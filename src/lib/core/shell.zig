const std = @import("std");
const IO = @import("./io.zig").IO;
const pwd = @import("./utils.zig").pwd;
const clear = @import("./utils.zig").clear;
const Editor = @import("./file-system.zig").Editor;
const ErrorHandler = @import("./error-handler.zig").ErrorHandler;
const openEditor = @import("./utils.zig").openEditor;
const getCommandIsInPATH = @import("./utils.zig").getCommandIsInPATH;

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
