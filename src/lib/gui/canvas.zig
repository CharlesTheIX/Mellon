const std = @import("std");
const rl = @import("raylib");
const Camera = @import("./camera.zig").Camera;
const Window = @import("./window.zig").Window;
const Key = @import("./input_handler.zig").Key;
const InputHandler = @import("./input_handler.zig").InputHandler;

pub const Canvas = struct {
    rect: rl.Rectangle,
    font_size: i32 = 16,
    font_loaded: bool = false,
    custom_font: ?rl.Font = null,
    selection_start: ?rl.Vector2 = null,
    selection_end: ?rl.Vector2 = null,

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

    fn windowToCanvasCoord(self: *Canvas, window_pos: rl.Vector2, camera: *const Camera) rl.Vector2 {
        // Transform window coordinates to canvas coordinates accounting for camera rotation, zoom, and offset
        // Steps: translate by offset → un-rotate → un-scale → add camera target

        // Step 1: Translate from screen space to camera-centered space
        var pos = window_pos.subtract(camera.camera.offset);

        // Step 2: Un-rotate by negative camera rotation to align with canvas
        pos = self.rotateVector(pos, -camera.camera.rotation);

        // Step 3: Un-scale by zoom
        pos = pos.scale(1.0 / camera.camera.zoom);

        // Step 4: Translate to world space by adding camera target
        return pos.add(camera.camera.target);
    }

    fn rotateVector(self: *Canvas, vec: rl.Vector2, angle_degrees: f32) rl.Vector2 {
        _ = self;
        const angle_radians = angle_degrees * std.math.pi / 180.0;
        const cos_a = @cos(angle_radians);
        const sin_a = @sin(angle_radians);
        return .{
            .x = vec.x * cos_a - vec.y * sin_a,
            .y = vec.x * sin_a + vec.y * cos_a,
        };
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
            self.drawLine(from, to, Color.Orange.toRL(50));
        }

        for (0..@as(usize, @intCast(rows))) |row| {
            const y = @as(f32, @floatFromInt(@as(i32, @intCast(row * gap))));
            const from = rl.Vector2{ .x = 0, .y = y };
            const to = rl.Vector2{ .x = self.rect.width, .y = y };
            self.drawLine(from, to, Color.Orange.toRL(50));
        }

        var from = rl.Vector2{ .x = 0, .y = self.rect.height };
        var to = rl.Vector2{ .x = self.rect.width, .y = self.rect.height };
        self.drawLine(from, to, Color.Orange.toRL(50));

        from = rl.Vector2{ .x = self.rect.width, .y = 0 };
        to = rl.Vector2{ .x = self.rect.width, .y = self.rect.height };
        self.drawLine(from, to, Color.Orange.toRL(50));
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

    pub fn drawMouseTile(self: *Canvas, mouse_pos: rl.Vector2, clr: rl.Color) void {
        const tile_size = 16.0;
        const tile_col = @as(f32, @divFloor(mouse_pos.x, tile_size));
        const tile_row = @as(f32, @divFloor(mouse_pos.y, tile_size));
        if (tile_col < 0 or tile_row < 0) return;
        if (tile_col >= @as(f32, @divFloor(self.rect.width, tile_size))) return;
        if (tile_row >= @as(f32, @divFloor(self.rect.height, tile_size))) return;
        const rect = rl.Rectangle{
            .width = tile_size,
            .height = tile_size,
            .y = tile_row * tile_size,
            .x = tile_col * tile_size,
        };
        self.drawRect(rect, clr);
    }

    pub fn drawMouseWindowTile(self: *Canvas, mouse_pos: rl.Vector2) void {
        const tile_size = 16.0;
        const tile_col = @as(f32, @divFloor(mouse_pos.x, tile_size));
        const tile_row = @as(f32, @divFloor(mouse_pos.y, tile_size));
        const rect = rl.Rectangle{
            .width = tile_size,
            .height = tile_size,
            .y = tile_row * tile_size,
            .x = tile_col * tile_size,
        };
        self.drawRect(rect, Color.Red.toRL(100));
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

    // SELECTION -------------------------------------------------------------------------
    fn resetSelection(self: *Canvas) void {
        self.selection_start = null;
        self.selection_end = null;
    }

    pub fn selectionRect(self: *Canvas, camera: *Camera) ?rl.Rectangle {
        const window_rect = self.selectionWindowRect() orelse return null;
        const top_left = self.windowToCanvasCoord(
            rl.Vector2{ .x = window_rect.x, .y = window_rect.y },
            camera,
        );
        const bottom_right = self.windowToCanvasCoord(
            rl.Vector2{ .x = window_rect.x + window_rect.width, .y = window_rect.y + window_rect.height },
            camera,
        );
        const x1 = @min(top_left.x, bottom_right.x);
        const y1 = @min(top_left.y, bottom_right.y);
        const x2 = @max(top_left.x, bottom_right.x);
        const y2 = @max(top_left.y, bottom_right.y);
        return rl.Rectangle{ .x = x1, .y = y1, .width = x2 - x1, .height = y2 - y1 };
    }

    pub fn selectionTileRect(self: *Canvas, camera: *Camera) ?rl.Rectangle {
        const rect = self.selectionRect(camera) orelse return null;
        const tile_size = 16.0;
        const x1 = @as(f32, @divFloor(rect.x, tile_size)) * tile_size;
        const y1 = @as(f32, @divFloor(rect.y, tile_size)) * tile_size;
        const x2 = @as(f32, @divFloor(rect.x + rect.width, tile_size) + 1) * tile_size;
        const y2 = @as(f32, @divFloor(rect.y + rect.height, tile_size) + 1) * tile_size;
        return rl.Rectangle{ .x = x1, .y = y1, .width = x2 - x1, .height = y2 - y1 };
    }

    pub fn selectionWindowRect(self: *Canvas) ?rl.Rectangle {
        const start = self.selection_start orelse return null;
        const end = self.selection_end orelse return null;
        const x1 = @min(start.x, end.x);
        const y1 = @min(start.y, end.y);
        const x2 = @max(start.x, end.x);
        const y2 = @max(start.y, end.y);
        return rl.Rectangle{ .x = x1, .y = y1, .width = x2 - x1, .height = y2 - y1 };
    }

    pub fn selectionWindowTileRect(self: *Canvas) ?rl.Rectangle {
        const tile_size = 16.0;
        const rect = self.selectionWindowRect() orelse return null;
        const x1 = @as(f32, @divFloor(rect.x, tile_size)) * tile_size;
        const y1 = @as(f32, @divFloor(rect.y, tile_size)) * tile_size;
        const x2 = @as(f32, @divFloor(rect.x + rect.width, tile_size) + 1) * tile_size;
        const y2 = @as(f32, @divFloor(rect.y + rect.height, tile_size) + 1) * tile_size;
        return rl.Rectangle{ .x = x1, .y = y1, .width = x2 - x1, .height = y2 - y1 };
    }

    pub fn updateSelection(self: *Canvas, input_handler: *InputHandler) void {
        const has_modifier = input_handler.keys.contains(&[_]Key{ .LeftShift, .RightShift }, .Or);
        if (has_modifier == false) return self.resetSelection();
        if (input_handler.mouse.active_clicks.get(.Left) != null) {
            const mouse_pos = input_handler.mouse.v2_window();
            if (self.selection_start == null) {
                self.selection_start = mouse_pos;
                self.selection_end = mouse_pos;
            } else {
                self.selection_end = mouse_pos;
            }
        }
    }
};

pub const Color = enum {
    Black,
    Blue,
    Green,
    Orange,
    Red,
    White,
    Yellow,

    pub fn toRL(self: Color, a: ?u8) rl.Color {
        switch (self) {
            .Black => return rl.Color{ .r = 55, .g = 55, .b = 55, .a = a orelse 255 },
            .Blue => return rl.Color{ .r = 0, .g = 0, .b = 255, .a = a orelse 255 },
            .Green => return rl.Color{ .r = 0, .g = 255, .b = 0, .a = a orelse 255 },
            .Orange => return rl.Color{ .r = 255, .g = 165, .b = 0, .a = a orelse 255 },
            .Red => return rl.Color{ .r = 255, .g = 0, .b = 0, .a = a orelse 255 },
            .White => return rl.Color{ .r = 255, .g = 255, .b = 255, .a = a orelse 255 },
            .Yellow => return rl.Color{ .r = 255, .g = 255, .b = 0, .a = a orelse 255 },
        }
    }
};
