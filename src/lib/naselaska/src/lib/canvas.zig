const std = @import("std");
const rl = @import("raylib");
const Camera = @import("./camera.zig").Camera;

pub const Canvas = struct {
    rect: rl.Rectangle,
    font_size: i32 = 16,
    font_loaded: bool = false,
    custom_font: ?rl.Font = null,

    // Static Methods
    pub fn init(width: f32, height: f32) Canvas {
        const rect = rl.Rectangle{ .x = 0, .y = 0, .width = width, .height = height };
        return Canvas{ .rect = rect };
    }

    // Instance Methods
    pub fn drawRect(self: *Canvas, x: i32, y: i32, width: i32, height: i32, color: rl.Color) void {
        _ = self;
        rl.drawRectangle(x, y, width, height, color);
    }

    pub fn drawText(self: *Canvas, text: []const u8, x: i32, y: i32, color: rl.Color) void {
        const alloc = std.heap.page_allocator;
        const text_z = alloc.allocSentinel(u8, text.len, 0) catch return;
        @memcpy(text_z, text);
        if (self.font_loaded and self.custom_font != null) {
            const font = self.custom_font.?;
            const font_size_f = @as(f32, @floatFromInt(self.font_size));
            const spacing = font_size_f / 10.0; // Spacing typically 10% of font size
            const pos = rl.Vector2{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
            rl.drawTextEx(font, text_z, pos, font_size_f, spacing, color);
        } else rl.drawText(text_z, x, y, self.font_size, color);
        alloc.free(text_z);
    }

    pub fn deinit(self: *Canvas) void {
        self.unload();
    }

    pub fn handleResize(self: *Canvas, camera: *Camera) void {
        const new_width = @as(f32, @floatFromInt(rl.getScreenWidth()));
        const new_height = @as(f32, @floatFromInt(rl.getScreenHeight()));
        self.rect.width = new_width;
        self.rect.height = new_height;
        camera.camera.offset.x = new_width / 2.0;
        camera.camera.offset.y = new_height / 2.0;
    }

    pub fn load(self: *Canvas, font_path: [:0]const u8) void {
        self.unload();
        self.custom_font = rl.loadFontEx(font_path, self.font_size, null) catch null;
        if (self.custom_font == null) return;
        self.font_loaded = true;
    }

    pub fn lineSpacing(self: *Canvas, multi: i32) i32 {
        return @divFloor(self.font_size, 2) * multi;
    }

    fn unload(self: *Canvas) void {
        if (!self.font_loaded or self.custom_font == null) return;
        rl.unloadFont(self.custom_font.?);
        self.custom_font = null;
        self.font_loaded = false;
    }
};
