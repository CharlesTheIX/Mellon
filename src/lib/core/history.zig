const std = @import("std");
const ErrorHandler = @import("./error-handler.zig").ErrorHandler;

pub const History = struct {
    log_dir: ?[]u8,
    max_size: u9 = 511,
    Err: *ErrorHandler,
    current_index: ?u9 = null,
    allocator: std.mem.Allocator,
    history: std.ArrayList([]u8),

    pub fn init(alloc: std.mem.Allocator, Err: *ErrorHandler, log_dir: ?[]u8) History {
        var history = History{
            .log_dir = log_dir,
            .Err = Err,
            .allocator = alloc,
            .history = std.ArrayList([]u8){},
        };
        history.load() catch |err| history.Err.handle(err, "Failed to load command history\n\n", false, true);
        return history;
    }

    // Methods
    pub fn add(self: *History, command: []const u8) void {
        if (command.len == 0) return;
        if (self.history.items.len > 0) {
            const last = self.history.items[self.history.items.len - 1];
            if (std.mem.eql(u8, last, command)) {
                self.current_index = null;
                return;
            }
        }
        const cmd_copy = self.allocator.dupe(u8, command) catch {
            self.Err.handle(error.OutOfMemory, "Failed to allocate memory for command history\n\n", false, true);
            return;
        };
        self.history.append(self.allocator, cmd_copy) catch |err| {
            self.Err.handle(err, "Failed to add command to history\n\n", false, true);
            self.allocator.free(cmd_copy);
            return;
        };
        self.current_index = null;
        while (self.history.items.len > self.max_size) {
            const first = self.history.orderedRemove(0);
            self.allocator.free(first);
        }
        self.save() catch |err| return self.Err.handle(err, "Failed to save command history\n\n", false, true);
    }

    pub fn deinit(self: *History) void {
        self.save() catch |err| self.Err.handle(err, "Failed to save command history\n\n", false, true);
        for (self.history.items) |cmd| self.allocator.free(cmd);
        self.history.deinit(self.allocator);
        if (self.log_dir) |log_dir| self.allocator.free(log_dir);
    }

    fn load(self: *History) !void {
        if (self.log_dir) |log_dir| {
            const file = try std.fs.openFileAbsolute(log_dir, .{ .mode = .read_only });
            defer file.close();
            const file_size = try file.getEndPos();
            if (file_size == 0) return error.FileNotFound;
            const buffer = try self.allocator.alloc(u8, file_size);
            defer self.allocator.free(buffer);
            const bytes_read = try file.readAll(buffer);
            if (bytes_read != file_size) return error.IncompleteRead;
            var lines = std.mem.splitScalar(u8, buffer, '\n');
            while (lines.next()) |line| {
                const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
                if (trimmed.len == 0) continue;
                if (self.history.items.len > 0) {
                    const last = self.history.items[self.history.items.len - 1];
                    if (std.mem.eql(u8, last, trimmed)) continue;
                }
                const cmd_copy = try self.allocator.dupe(u8, trimmed);
                try self.history.append(self.allocator, cmd_copy);
            }
            while (self.history.items.len > self.max_size) {
                const first = self.history.orderedRemove(0);
                self.allocator.free(first);
            }
            return;
        }
        return error.NoConfigPath;
    }

    pub fn navigateDown(self: *History) ?[]const u8 {
        if (self.current_index) |idx| {
            if (idx < self.history.items.len - 1) {
                self.current_index = idx + 1;
                return self.history.items[self.current_index.?];
            } else {
                self.current_index = null;
                return "";
            }
        }
        return null;
    }

    pub fn navigateUp(self: *History) ?[]const u8 {
        if (self.history.items.len == 0) return null;
        if (self.current_index) |idx| {
            if (idx > 0) self.current_index = idx - 1;
        } else self.current_index = @as(u9, @intCast(self.history.items.len - 1));
        if (self.current_index) |idx| return self.history.items[idx];
        return null;
    }

    pub fn reset(self: *History) void {
        self.current_index = null;
    }

    fn save(self: *const History) !void {
        if (self.log_dir) |log_dir| {
            const file = try std.fs.createFileAbsolute(log_dir, .{});
            defer file.close();
            var buffer: [4096]u8 = undefined;
            var writer = file.writer(&buffer);
            for (self.history.items) |cmd| {
                try writer.interface.writeAll(cmd);
                try writer.interface.writeByte('\n');
            }
            try writer.interface.flush();
            return;
        }
        return error.NoConfigPath;
    }
};
