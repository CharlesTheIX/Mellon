const std = @import("std");
const rl = @import("raylib");
const D_IO = @import("./draw-io.zig");
const Map = @import("../map.zig").Map;
const D_Map = @import("./draw-map.zig");
const Timer = @import("../timer.zig").Timer;
const D_Camera = @import("./draw-camera.zig");
const D_Canvas = @import("./draw-canvas.zig");
const Canvas = @import("../canvas.zig").Canvas;
const Camera = @import("../camera.zig").Camera;
const Key = @import("../input-handler.zig").Key;
const Click = @import("../input-handler.zig").Click;
const AH = @import("../audio-handler.zig").AudioHandler;
const IH = @import("../input-handler.zig").InputHandler;

pub const Dev = struct {
    show_info: bool = false,
    active_window: Window = .Main,
    timer: Timer = Timer.init(500_000_000),

    // Static methods
    fn contentAreaPadding(canvas: *Canvas) i32 {
        return @as(i32, @intFromFloat(canvas.*.rect.width * 0.1));
    }

    fn draw_camera(canvas: *Canvas, camera: *Camera) void {
        var padding = [2]i32{ contentAreaPadding(canvas), contentAreaPadding(canvas) };
        padding = drawTitle("CAMERA INFO", padding, canvas, true);
        _ = D_Camera.camera(canvas, camera, padding);
    }

    fn draw_canvas(canvas: *Canvas) void {
        var padding = [2]i32{ contentAreaPadding(canvas), contentAreaPadding(canvas) };
        padding = drawTitle("CANVAS INFO", padding, canvas, true);
        _ = D_Canvas.canvas(canvas, padding);
    }

    fn draw_io(canvas: *Canvas, ih: *IH, camera: *Camera, music_player: *AH, sfx_player: *AH) void {
        var padding = [2]i32{ contentAreaPadding(canvas), contentAreaPadding(canvas) };
        padding = drawTitle("INPUT / OUTPUT", padding, canvas, true);
        padding = D_IO.clicks(canvas, ih, padding);
        padding = D_IO.keys(canvas, ih, padding);
        padding = D_IO.mouse(canvas, ih, camera, padding);
        padding[1] += canvas.lineSpacing(2);
        padding[0] = contentAreaPadding(canvas);

        const sub_pad = padding;
        padding = drawTitle("Music", padding, canvas, true);
        _ = D_IO.audio(canvas, .Music, music_player, padding);
        padding = sub_pad;
        padding[0] = @divFloor(@as(i32, @intFromFloat(canvas.rect.width)), 2);
        padding = drawTitle("SFX", padding, canvas, true);
        _ = D_IO.audio(canvas, .Sound, sfx_player, padding);
    }

    fn draw_main(canvas: *Canvas) void {
        var padding = [2]i32{ contentAreaPadding(canvas), contentAreaPadding(canvas) };
        padding = drawTitle("MAIN INFO", padding, canvas, true);
        canvas.drawText("This is the main debug window. You can put any info here that doesn't fit in the other categories.", padding[0], padding[1], rl.Color.black);
    }

    fn draw_map(canvas: *Canvas, map_obj: *Map) void {
        var padding = [2]i32{ contentAreaPadding(canvas), contentAreaPadding(canvas) };
        padding = drawTitle("MAP INFO", padding, canvas, true);
        _ = D_Map.map(canvas, map_obj, padding);
    }

    fn draw_player(canvas: *Canvas) void {
        var padding = [2]i32{ contentAreaPadding(canvas), contentAreaPadding(canvas) };
        padding = drawTitle("PLAYER INFO", padding, canvas, true);
        canvas.drawText("Player info would go here. This is a placeholder for now.", padding[0], padding[1], rl.Color.black);
    }

    fn drawBackground(canvas: *Canvas) void {
        canvas.drawRect(
            0,
            0,
            @as(i32, @intFromFloat(canvas.*.rect.width)),
            @as(i32, @intFromFloat(canvas.*.rect.height)),
            rl.Color.black.alpha(0.5),
        );
    }

    fn drawContentArea(canvas: *Canvas) void {
        canvas.drawRect(
            contentAreaPadding(canvas),
            contentAreaPadding(canvas),
            @as(i32, @intFromFloat(canvas.*.rect.width - 2 * @as(f32, @floatFromInt(contentAreaPadding(canvas))))),
            @as(i32, @intFromFloat(canvas.*.rect.height - 2 * @as(f32, @floatFromInt(contentAreaPadding(canvas))))),
            rl.Color.white.alpha(0.5),
        );
    }

    fn drawTabs(canvas: *Canvas, active_window: Window) void {
        const tab_height = canvas.lineSpacing(3);
        const tab_width = canvas.*.rect.width / @as(f32, @floatFromInt(Window.getIterator().len));
        var x_offset: f32 = 0;
        for (Window.getIterator(), 0..) |window, i| {
            const name = window.toStringZ();
            const is_active = window == active_window;
            const alloc = std.heap.page_allocator;
            const clr = if (is_active) rl.Color.white else rl.Color.white.alpha(0.5);
            const tab_text = std.fmt.allocPrint(alloc, "{s} ({d})", .{ name, i + 1 }) catch name;
            defer if (tab_text.ptr != name.ptr) alloc.free(tab_text);
            canvas.drawRect(@intFromFloat(x_offset), 0, @intFromFloat(tab_width), @as(i32, tab_height), clr);
            canvas.drawText(
                tab_text,
                @as(i32, @intFromFloat(x_offset)) + canvas.lineSpacing(1),
                @divFloor(canvas.lineSpacing(1), 2),
                rl.Color.black,
            );
            x_offset += tab_width;
        }
    }

    fn drawTitle(title: []const u8, padding: [2]i32, canvas: *Canvas, with_hr: bool) [2]i32 {
        var y = padding[1] + canvas.lineSpacing(1);
        const x = padding[0] + canvas.lineSpacing(1);
        canvas.drawText(title, x, y, rl.Color.black);
        if (with_hr) {
            y += canvas.lineSpacing(2);
            canvas.drawText("-----------------------------------", x, y, rl.Color.black);
        }
        y += canvas.lineSpacing(4);
        return .{ x, y };
    }

    pub fn init() Dev {
        return Dev{};
    }

    // Instance methods
    pub fn draw(self: *Dev, ih: *IH, camera: *Camera, map: *Map, canvas: *Canvas, music_player: *AH, sfx_player: *AH) void {
        if (!self.show_info) return;
        drawBackground(canvas);
        drawContentArea(canvas);
        drawTabs(canvas, self.active_window);
        switch (self.active_window) {
            .Camera => draw_camera(canvas, camera),
            .Canvas => draw_canvas(canvas),
            .IO => draw_io(canvas, ih, camera, music_player, sfx_player),
            .Map => draw_map(canvas, map),
            .Main => draw_main(canvas),
            .Player => draw_player(canvas),
        }
    }

    pub fn update(self: *Dev, ih: *IH) void {
        if (self.timer.state == .Running) return self.timer.update();
        if (ih.keysActive(&[_]Key{ .LeftShift, .LeftControl, .Zero }, .And)) {
            self.show_info = !self.show_info;
            return self.timer.start();
        }
        if (!self.show_info) return;
        if (ih.keysActive(&[_]Key{.One}, .And)) {
            self.active_window = .Camera;
        } else if (ih.keysActive(&[_]Key{.Two}, .And)) {
            self.active_window = .Canvas;
        } else if (ih.keysActive(&[_]Key{.Three}, .And)) {
            self.active_window = .IO;
        } else if (ih.keysActive(&[_]Key{.Four}, .And)) {
            self.active_window = .Main;
        } else if (ih.keysActive(&[_]Key{.Five}, .And)) {
            self.active_window = .Map;
        } else if (ih.keysActive(&[_]Key{.Six}, .And)) {
            self.active_window = .Player;
        } else return;
        self.timer.start();
    }
};

pub const Window = enum {
    Camera,
    Canvas,
    IO,
    Main,
    Map,
    Player,

    pub fn getIterator() []const Window {
        return std.enums.values(Window);
    }

    pub fn toStringZ(self: Window) [:0]const u8 {
        return switch (self) {
            .Camera => "Camera",
            .Canvas => "Canvas",
            .IO => "IO",
            .Main => "Main",
            .Map => "Map",
            .Player => "Player",
        };
    }
};
