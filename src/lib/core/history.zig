const std = @import("std");

pub const History = struct {
    current_index: ?usize,
    allocator: std.mem.Allocator,
    commands: std.ArrayList([]u8),

    // Static Methods
    pub fn init(alloc: std.mem.Allocator) History {
        return History{
            .current_index = null,
            .allocator = alloc,
            .commands = std.ArrayList([]u8).empty,
        };
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
    }

    pub fn deinit(self: *History) void {
        for (self.commands.items) |cmd| self.allocator.free(cmd);
        self.commands.deinit(self.allocator);
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
};
