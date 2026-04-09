const std = @import("std");
const rl = @import("raylib");
const Camera = @import("./camera.zig").Camera;
const Window = @import("./window.zig").Window;

pub const Canvas = struct {
    rect: rl.Rectangle,
    font_size: i32 = 16,
    font_loaded: bool = false,
    custom_font: ?rl.Font = null,

    pub fn init(window: *Window) Canvas {
        return Canvas{ .rect = window.asRectangle() };
    }

    pub fn deinit(self: *Canvas) void {
        if (!self.font_loaded or self.custom_font == null) return;
        rl.unloadFont(self.custom_font.?);
        self.custom_font = null;
        self.font_loaded = false;
    }

    // . -------------------------------------------------------------------------
    pub fn lineSpacing(self: *Canvas, multi: i32) i32 {
        return @divFloor(self.font_size, 2) * multi;
    }

    pub fn load(self: *Canvas) void {
        self.custom_font = rl.loadFontEx("./assets/fonts/JetBrains.ttf", self.font_size, null) catch null;
        if (self.custom_font == null) return;
        self.font_loaded = true;
    }

    pub fn resize(self: *Canvas, new_rect: rl.Rectangle) void {
        self.rect = new_rect;
    }

    // DRAW -------------------------------------------------------------------------
    pub fn drawGrid(self: *Canvas) void {
        const gap = 16;
        const cols = @divFloor(@as(i32, @intFromFloat(self.rect.width)), gap);
        const rows = @divFloor(@as(i32, @intFromFloat(self.rect.height)), gap);
        for (0..@as(usize, @intCast(cols))) |col| {
            const x = @as(f32, @floatFromInt(@as(i32, @intCast(col * gap))));
            const from = rl.Vector2{ .x = x, .y = 0 };
            const to = rl.Vector2{ .x = x, .y = self.rect.height };
            self.drawLine(from, to, rl.Color.white);
        }

        for (0..@as(usize, @intCast(rows))) |row| {
            const y = @as(f32, @floatFromInt(@as(i32, @intCast(row * gap))));
            const from = rl.Vector2{ .x = 0, .y = y };
            const to = rl.Vector2{ .x = self.rect.width, .y = y };
            self.drawLine(from, to, rl.Color.white);
        }

        var from = rl.Vector2{ .x = 0, .y = self.rect.height };
        var to = rl.Vector2{ .x = self.rect.width, .y = self.rect.height };
        self.drawLine(from, to, Color.Yellow.toRL(100));

        from = rl.Vector2{ .x = self.rect.width, .y = 0 };
        to = rl.Vector2{ .x = self.rect.width, .y = self.rect.height };
        self.drawLine(from, to, Color.Yellow.toRL(100));
    }

    pub fn drawWindowGrid(self: *Canvas, window: *Window) void {
        const gap = 16;
        const cols = @divFloor(window.width, gap);
        const rows = @divFloor(window.height, gap);
        for (0..@as(usize, @intCast(cols))) |col| {
            const x = @as(f32, @floatFromInt(@as(i32, @intCast(col * gap))));
            const from = rl.Vector2{ .x = x, .y = 0 };
            const to = rl.Vector2{ .x = x, .y = self.rect.height };
            self.drawLine(from, to, Color.White.toRL(50));
        }

        for (0..@as(usize, @intCast(rows))) |row| {
            const y = @as(f32, @floatFromInt(@as(i32, @intCast(row * gap))));
            const from = rl.Vector2{ .x = 0, .y = y };
            const to = rl.Vector2{ .x = self.rect.width, .y = y };
            self.drawLine(from, to, Color.White.toRL(50));
        }
    }

    pub fn drawLine(self: *Canvas, from: rl.Vector2, to: rl.Vector2, color: rl.Color) void {
        _ = self;
        const to_x = @as(i32, @intFromFloat(to.x));
        const to_y = @as(i32, @intFromFloat(to.y));
        const from_x = @as(i32, @intFromFloat(from.x));
        const from_y = @as(i32, @intFromFloat(from.y));
        rl.drawLine(from_x, from_y, to_x, to_y, color);
    }

    pub fn drawRect(self: *Canvas, rect: rl.Rectangle, clr: rl.Color) void {
        _ = self;
        rl.drawRectangleRec(rect, clr);
    }

    pub fn drawText(self: *Canvas, text: []const u8, pos: rl.Vector2, color: rl.Color) void {
        var needs_free = false;
        var text_z: [:0]u8 = undefined;
        var stack_buf: [256]u8 = undefined;
        const alloc = std.heap.page_allocator;
        if (text.len + 1 <= stack_buf.len) {
            text_z = std.fmt.bufPrintZ(&stack_buf, "{s}", .{text}) catch return;
        } else {
            text_z = alloc.allocSentinel(u8, text.len, 0) catch return;
            @memcpy(text_z, text);
            needs_free = true;
        }
        defer if (needs_free) alloc.free(text_z);
        if (self.font_loaded and self.custom_font != null) {
            const font = self.custom_font.?;
            const font_size_f = @as(f32, @floatFromInt(self.font_size));
            const spacing = font_size_f / 10.0; // Spacing typically 10% of font size
            rl.drawTextEx(font, text_z, pos, font_size_f, spacing, color);
        } else {
            const x = @as(i32, @floatFromInt(pos.x));
            const y = @as(i32, @floatFromInt(pos.y));
            rl.drawText(text_z, x, y, self.font_size, color);
        }
    }
};

pub const Color = enum {
    Black,
    Blue,
    Green,
    Red,
    White,
    Yellow,

    pub fn toRL(self: Color, a: ?u8) rl.Color {
        switch (self) {
            .Black => return rl.Color{ .r = 55, .g = 55, .b = 55, .a = a orelse 255 },
            .Blue => return rl.Color{ .r = 0, .g = 0, .b = 255, .a = a orelse 255 },
            .Green => return rl.Color{ .r = 0, .g = 255, .b = 0, .a = a orelse 255 },
            .Red => return rl.Color{ .r = 255, .g = 0, .b = 0, .a = a orelse 255 },
            .White => return rl.Color{ .r = 255, .g = 255, .b = 255, .a = a orelse 255 },
            .Yellow => return rl.Color{ .r = 255, .g = 255, .b = 0, .a = a orelse 255 },
        }
    }
};
