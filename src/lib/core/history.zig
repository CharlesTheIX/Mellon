const std = @import("std");

pub const History = struct {
    max_size: usize,
    current_index: ?usize,
    history_path: []const u8,
    allocator: std.mem.Allocator,
    commands: std.ArrayList([]u8),

    // Static Methods
    pub fn init(alloc: std.mem.Allocator) History {
        const home = std.posix.getenv("HOME") orelse "~";
        const history_path = std.fmt.allocPrint(alloc, "{s}/.mellon_history", .{home}) catch "";
        var history = History{
            .max_size = 1000,
            .current_index = null,
            .allocator = alloc,
            .history_path = history_path,
            .commands = std.ArrayList([]u8){},
        };
        history.load() catch {};
        return history;
    }

    // Instance Methods
    pub fn add(self: *History, command: []const u8) !void {
        if (command.len == 0) return;
        if (self.commands.items.len > 0) {
            const last = self.commands.items[self.commands.items.len - 1];
            if (std.mem.eql(u8, last, command)) {
                self.current_index = null;
                return;
            }
        }
        const cmd_copy = try self.allocator.dupe(u8, command);
        try self.commands.append(self.allocator, cmd_copy);
        self.current_index = null;

        while (self.commands.items.len > self.max_size) {
            const first = self.commands.orderedRemove(0);
            self.allocator.free(first);
        }

        self.save() catch {};
    }

    pub fn deinit(self: *History) void {
        self.save() catch {};
        for (self.commands.items) |cmd| self.allocator.free(cmd);
        self.commands.deinit(self.allocator);
        if (self.history_path.len > 0) self.allocator.free(self.history_path);
    }

    pub fn navigateDown(self: *History) ?[]const u8 {
        if (self.current_index) |idx| {
            if (idx < self.commands.items.len - 1) {
                self.current_index = idx + 1;
                return self.commands.items[self.current_index.?];
            } else {
                self.current_index = null;
                return "";
            }
        }
        return null;
    }

    pub fn navigateUp(self: *History) ?[]const u8 {
        if (self.commands.items.len == 0) return null;
        if (self.current_index) |idx| {
            if (idx > 0) self.current_index = idx - 1;
        } else self.current_index = self.commands.items.len - 1;
        if (self.current_index) |idx| return self.commands.items[idx];
        return null;
    }

    pub fn reset(self: *History) void {
        self.current_index = null;
    }

    fn load(self: *History) !void {
        if (self.history_path.len == 0) return;

        const file = std.fs.openFileAbsolute(self.history_path, .{ .mode = .read_only }) catch |err| {
            if (err == error.FileNotFound) return;
            return err;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        if (file_size == 0) return;

        const buffer = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(buffer);

        const bytes_read = try file.readAll(buffer);
        if (bytes_read != file_size) return error.IncompleteRead;

        var lines = std.mem.splitScalar(u8, buffer, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0) continue;
            if (self.commands.items.len > 0) {
                const last = self.commands.items[self.commands.items.len - 1];
                if (std.mem.eql(u8, last, trimmed)) continue;
            }

            const cmd_copy = try self.allocator.dupe(u8, trimmed);
            try self.commands.append(self.allocator, cmd_copy);
        }

        while (self.commands.items.len > self.max_size) {
            const first = self.commands.orderedRemove(0);
            self.allocator.free(first);
        }
    }

    fn save(self: *const History) !void {
        if (self.history_path.len == 0) return;
        const file = try std.fs.createFileAbsolute(self.history_path, .{});
        defer file.close();
        var buffer: [4096]u8 = undefined;
        var writer = file.writer(&buffer);
        for (self.commands.items) |cmd| {
            try writer.interface.writeAll(cmd);
            try writer.interface.writeByte('\n');
        }
        try writer.interface.flush();
    }
};
