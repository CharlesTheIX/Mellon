const std = @import("std");
const IO = @import("../core/io.zig").IO;
const FS = @import("../core/file-system.zig").FileSystem;

pub const Map = struct {
    fs: *FS,
    age: u8,
    id: []const u8,
    name: []const u8,

    // Static Methods
    pub fn init(fs: *FS) Map {
        return Map{ .id = "", .age = 0, .name = "", .fs = fs };
    }

    // Instance Methods
    pub fn load(self: *Map, id: []const u8) !void {
        self.id = "";
        self.age = 0;
        self.name = "";

        const path = std.fmt.allocPrint(std.heap.page_allocator, "./.test-data/map_{s}.z", .{id}) catch return;
        defer std.heap.page_allocator.free(path);
        const data = self.fs.readFile(path) catch return;
        var entries = std.mem.splitSequence(u8, data, "\n");

        self.id = id;
        while (entries.next()) |entry| {
            var key_value = std.mem.splitSequence(u8, entry, ":");
            const key = key_value.first();
            const value = key_value.rest();
            if (std.mem.eql(u8, key, "name")) self.name = value;
            if (std.mem.eql(u8, key, "age")) self.age = std.fmt.parseInt(u8, value, 10) catch 0;
        }
    }

    fn save(self: *const Map) !void {
        if (self.id.len == 0) return;
        const path = std.fmt.allocPrint(std.heap.page_allocator, "./.test-data/map_{s}.z", .{self.id}) catch return;
        const file = try std.fs.createFileAbsolute(path.config_path, .{});
        defer file.close();

        var buffer: [2048]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buffer);
        const writer = stream.writer();

        try writer.print("age={d}\n", .{self.age});
        try writer.print("name={s}\n", .{self.name});
        try file.writeAll(stream.getWritten());
    }
};
