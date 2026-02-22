const std = @import("std");
const rl = @import("raylib");
const Map = @import("./lib/map.zig").Map;
const Timer = @import("./lib/timer.zig").Timer;
const Canvas = @import("./lib/canvas.zig").Canvas;
const Key = @import("./lib/input-handler.zig").Key;
const IH = @import("./lib/input-handler.zig").InputHandler;

pub const NaseLaska = struct {
    ih: IH,
    map: Map,
    canvas: Canvas,

    timer: Timer,

    // Static Methods
    pub fn init(allocator: std.mem.Allocator) NaseLaska {
        const ih = IH.init(allocator);
        const canvas = Canvas.init(800, 600);
        const map = Map.init(allocator);
        return NaseLaska{
            .map = map,
            .ih = ih,
            .canvas = canvas,

            .timer = Timer.init(1000_000_000), // 1 second in nanoseconds
        };
    }

    // Instance Methods
    pub fn deinit(self: *NaseLaska) void {
        self.ih.deinit();
        self.map.deinit();
        self.canvas.deinit();
    }

    fn draw(self: *NaseLaska) void {
        self.map.draw(self.canvas.rect);
        self.ih.draw();
    }

    pub fn mainLoop(self: *NaseLaska) !void {
        rl.setTargetFPS(60);
        rl.initWindow(@intFromFloat(self.canvas.rect.width), @intFromFloat(self.canvas.rect.height), "Naše Láska");
        defer rl.closeWindow();

        self.map.load("test") catch return;

        while (!rl.windowShouldClose()) {
            rl.beginDrawing();
            rl.clearBackground(rl.Color.black);
            self.update();
            self.draw();
            rl.endDrawing();
        }
        return std.process.exit(0);
    }

    fn update(self: *NaseLaska) void {
        self.ih.update();

        self.timer.update();
        if (self.timer.state == .Finished or self.timer.state == .Ready) {
            if (self.ih.keysActive(&[_]Key{ .LeftShift, .A }, .And) and !std.mem.eql(u8, self.map.id, "test_2")) {
                self.timer.start();
                self.map.load("test_2") catch {};
            }

            if (self.ih.keysActive(&[_]Key{ .LeftShift, .D }, .And) and !std.mem.eql(u8, self.map.id, "test")) {
                self.timer.start();
                self.map.load("test") catch {};
            }

            if (self.ih.keysActive(&[_]Key{ .LeftShift, .W }, .And) and !std.mem.eql(u8, self.map.id, "test_3")) {
                self.timer.start();
                self.map.load("test_3") catch {};
            }

            if (self.ih.keysActive(&[_]Key{ .LeftShift, .S }, .And) and !std.mem.eql(u8, self.map.id, "test_4")) {
                self.timer.start();
                self.map.load("test_4") catch {};
            }
        }

        self.map.update();
    }
};
