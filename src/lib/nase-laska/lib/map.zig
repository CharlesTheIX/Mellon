const std = @import("std");
const rl = @import("raylib");
const readFile = @import("./utils.zig").readFile;

pub const Map = struct {
    id: []const u8 = "",
    name: []const u8 = "",
    allocator: std.mem.Allocator,
    bg_img: ?rl.Texture2D = null,
    spawn_points: []const u64 = &[_]u64{},
    data_dir: []const u8 = "./src/lib/nase-laska/data/maps",
    rect: rl.Rectangle = rl.Rectangle.init(0, 0, 0, 0),

    // Static Methods
    pub fn init(allocator: std.mem.Allocator) Map {
        return Map{ .allocator = allocator };
    }

    // Instance Methods
    pub fn drawWorld(self: *Map) void {
        if (self.bg_img) |texture| rl.drawTextureV(texture, rl.Vector2.zero(), rl.Color.white);

        // const alloc = std.heap.page_allocator;
        // const text = std.fmt.allocPrint(alloc, "ID: {s}\nName: {s}\nWidth: {d}\nHeight: {d}", .{
        //     self.id,
        //     self.name,
        //     self.rect.width,
        //     self.rect.height,
        // }) catch "Error";
        // defer alloc.free(text);
        // const text_z = alloc.allocSentinel(u8, text.len, 0) catch return;
        // @memcpy(text_z, text);
        // rl.drawText(text_z, 10, 10, 16, rl.Color.black);

        // for (self.spawn_points) |point| {
        //     const x = @as(f32, @floatFromInt(point & 0xFFFF));
        //     const y = @as(f32, @floatFromInt((point >> 16) & 0xFFFF));
        //     rl.drawCircleV(rl.Vector2{ .x = x, .y = y }, 5, rl.Color.red);
        // }
    }

    pub fn draw(self: *Map, canvas_rect: rl.Rectangle, camera_rect: rl.Rectangle) void {
        std.debug.print("Drawing map {s} with camera rect ({d}, {d}, {d}, {d})\n", .{ self.id, camera_rect.x, camera_rect.y, camera_rect.width, camera_rect.height });
        if (self.bg_img) |texture| {
            rl.drawTexturePro(
                texture,
                camera_rect,
                canvas_rect,
                rl.Vector2.zero(),
                0.0,
                rl.Color.white,
            );
        }

        const alloc = std.heap.page_allocator;
        const text = std.fmt.allocPrint(alloc, "ID: {s}\nName: {s}\nWidth: {d}\nHeight: {d}", .{
            self.id,
            self.name,
            self.rect.width,
            self.rect.height,
        }) catch "Error";
        defer alloc.free(text);
        const text_z = alloc.allocSentinel(u8, text.len, 0) catch return;
        @memcpy(text_z, text);
        rl.drawText(text_z, 190, 200, 16, rl.Color.black);

        for (self.spawn_points) |point| {
            const x = @as(f32, @floatFromInt(point & 0xFFFF));
            const y = @as(f32, @floatFromInt((point >> 16) & 0xFFFF));
            rl.drawCircleV(rl.Vector2{ .x = x, .y = y }, 5, rl.Color.red);
        }
    }

    pub fn deinit(self: *Map) void {
        if (self.bg_img) |texture| rl.unloadTexture(texture);
        self.id = "";
        self.name = "";
        self.bg_img = null;
        self.spawn_points = &[_]u64{};
        self.rect = rl.Rectangle.init(0, 0, 0, 0);
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

        const data = readFile(path);
        var entries = std.mem.splitSequence(u8, data, "\n");

        self.id = id;
        self.bg_img = bg_texture;
        while (entries.next()) |entry| {
            var key_value = std.mem.splitSequence(u8, entry, ":");
            const key = key_value.first();
            const value = key_value.rest();

            // string values are expected to be in the format key=value
            if (std.mem.eql(u8, key, "name")) self.name = value;

            // numeric values are expected to be in the format key=value
            if (std.mem.eql(u8, key, "width")) self.rect.width = @floatFromInt(std.fmt.parseInt(u32, value, 10) catch 0);
            if (std.mem.eql(u8, key, "height")) self.rect.height = @floatFromInt(std.fmt.parseInt(u32, value, 10) catch 0);

            // number list values are expected to be in the format key=value1|value2|value3
            if (std.mem.eql(u8, key, "spawn_points")) {
                var count: usize = 0;
                var spawn_points_buffer: [64]u64 = undefined;
                var points = std.mem.splitSequence(u8, value, "|");
                while (points.next()) |point| {
                    if (count >= spawn_points_buffer.len) break;
                    if (std.fmt.parseInt(u64, point, 10)) |p| {
                        spawn_points_buffer[count] = p;
                        count += 1;
                    } else |_| {}
                }
                self.spawn_points = self.allocator.dupe(u64, spawn_points_buffer[0..count]) catch &[_]u64{};
            }
        }
    }

    fn reset(self: *Map) void {
        self.id = "";
        self.name = "";
        self.rect = rl.Rectangle.init(0, 0, 0, 0);
        if (self.bg_img) |texture| rl.unloadTexture(texture);
        if (self.spawn_points.len > 0) self.allocator.free(self.spawn_points);
        self.bg_img = null;
        self.spawn_points = &[_]u64{};
    }

    pub fn save(self: *Map) !void {
        if (self.id.len == 0) return;
        const alloc = std.heap.page_allocator;
        const path = std.fmt.allocPrint(alloc, "{s}/map_{s}.z", .{ self.data_dir, self.id }) catch return;
        defer std.heap.page_allocator.free(path);

        var file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        var buffer: [2048]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buffer);
        const writer = stream.writer();
        const spawn_points = std.fmt.join(u8, self.spawn_points, "|", 10) catch "0";

        try writer.print("name={s}\n", .{self.name});
        try writer.print("width={d}\n", .{@intFromFloat(self.rect.width)});
        try writer.print("height={d}\n", .{@intFromFloat(self.rect.height)});
        try writer.print("spawn_points={s}\n", .{spawn_points});
        try file.writeAll(stream.getWritten());
    }

    pub fn update(self: *Map) void {
        _ = self;
    }
};
