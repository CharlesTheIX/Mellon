const std = @import("std");
const rl = @import("raylib");
const IO = @import("../core/io.zig").IO;
const FS = @import("../core/file-system.zig").FileSystem;

pub const Map = struct {
    fs: *FS,
    id: []const u8 = "",
    name: []const u8 = "",
    bg_img: ?rl.Texture2D = null,
    data_dir: []const u8 = "./src/lib/nase-laska/data/maps",

    // Static Methods
    pub fn init(fs: *FS) Map {
        return Map{ .fs = fs };
    }

    // Instance Methods
    pub fn draw(self: *Map, canvas_rect: rl.Rectangle) void {
        if (self.bg_img) |texture| {
            // Source rectangle (entire texture)
            const source_rect = rl.Rectangle{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(texture.width),
                .height = @floatFromInt(texture.height),
            };
            rl.drawTexturePro(
                texture,
                source_rect,
                canvas_rect,
                rl.Vector2.zero(),
                0.0,
                rl.Color.white,
            );
        }

        const alloc = std.heap.page_allocator;
        const text = std.fmt.allocPrint(alloc, "ID: {s}\nName: {s}", .{ self.id, self.name }) catch "Error";
        defer alloc.free(text);
        const text_z = alloc.allocSentinel(u8, text.len, 0) catch return;
        @memcpy(text_z, text);
        rl.drawText(text_z, 190, 200, 20, rl.Color.black);
    }

    pub fn load(self: *Map, id: []const u8) !void {
        self.reset();
        const alloc = std.heap.page_allocator;
        const path = std.fmt.allocPrint(alloc, "{s}/map_{s}.z", .{ self.data_dir, id }) catch return;
        defer std.heap.page_allocator.free(path);

        const bg_img_path = std.fmt.allocPrint(alloc, "{s}/map_{s}.png", .{ self.data_dir, id }) catch return;
        defer std.heap.page_allocator.free(bg_img_path);
        const bg_img_path_z = alloc.dupeZ(u8, bg_img_path) catch return;
        defer std.heap.page_allocator.free(bg_img_path_z);
        const bg_texture = try rl.loadTexture(bg_img_path_z);

        const data = self.fs.readFile(path) catch return;
        var entries = std.mem.splitSequence(u8, data, "\n");

        self.id = id;
        self.bg_img = bg_texture;
        while (entries.next()) |entry| {
            var key_value = std.mem.splitSequence(u8, entry, ":");
            const key = key_value.first();
            const value = key_value.rest();

            // string values are expected to be in the format key=value
            if (std.mem.eql(u8, key, "name")) self.name = value;
        }
    }

    fn reset(self: *Map) void {
        self.id = "";
        self.name = "";
        if (self.bg_img) |texture| {
            rl.unloadTexture(texture);
        }
        self.bg_img = null;
    }

    pub fn save(self: *Map) !void {
        if (self.id.len == 0) return;
        const alloc = std.heap.page_allocator;
        const path = std.fmt.allocPrint(alloc, "{s}/map_{s}.z", .{ self.data_dir, self.id }) catch return;
        defer std.heap.page_allocator.free(path);

        const file = try std.fs.createFileAbsolute(path.config_path, .{});
        defer file.close();
        var buffer: [2048]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buffer);
        const writer = stream.writer();
        try writer.print("name={s}\n", .{self.name});
        try file.writeAll(stream.getWritten());
    }

    pub fn update(self: *Map) void {
        _ = self;
    }
};
