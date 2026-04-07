const std = @import("std");
const readFile = @import("./utils.zig").readFile;

pub const ErrorHandler = struct {
    log_dir: ?[]const u8 = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ErrorHandler {
        return ErrorHandler{ .allocator = allocator };
    }

    // Methods
    pub fn handle(self: *ErrorHandler, err: anyerror, details: []const u8, fatal: bool, log_err: ?bool) void {
        var msg: []const u8 = "";
        switch (err) {
            error.OutOfMemory => msg = "Out of memory",
            error.FileNotFound => msg = "File not found",
            error.InvalidCommand => msg = "Invalid command",
            error.NoConfigPath => msg = "No config path specified",
            error.Unexpected => msg = "An unexpected error occurred",
            error.IncompleteRead => msg = "Incomplete read from file",
            error.NoLogDir => msg = "No log directory specified in config",
            error.InvalidEditor => msg = "Invalid editor specified in config",
            else => msg = "An unknown error occurred",
        }
        const timestamp = @divTrunc(std.time.timestamp(), 1000); // seconds
        std.debug.print("\n❌ [{d}] Error: {s}\nMessage: {s}\nDetails: {s}\n", .{ timestamp, @errorName(err), msg, details });
        if (log_err orelse false) {
            const log_message = std.fmt.allocPrint(
                self.allocator,
                "[{d}] Error: {s}\nMessage:{s}\nDetails: {s}\n\n",
                .{ timestamp, @errorName(err), msg, details },
            ) catch {
                std.debug.print("\n❌ Failed to allocate memory for log message\n", .{});
                if (fatal) std.process.exit(1);
                return;
            };
            defer self.allocator.free(log_message);
            self.log(log_message, "error") catch std.debug.print("❌ Failed to log error\n\n", .{});
        }
        if (fatal) std.process.exit(1);
    }

    fn log(self: *ErrorHandler, message: []const u8, log_name: ?[]const u8) !void {
        const log_dir = self.log_dir orelse return error.NoLogDir;
        if (log_dir.len == 0) return error.NoLogDir;
        const name = log_name orelse "log";
        const log_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}.log", .{ log_dir, name });
        defer self.allocator.free(log_path);
        const current_content = try readFile(log_path);
        const new_content = try std.fmt.allocPrint(self.allocator, "{s}\n{s}", .{ current_content, message });
        const file = try std.fs.createFileAbsolute(log_path, .{});
        defer file.close();
        try file.writeAll(new_content);
    }
};
