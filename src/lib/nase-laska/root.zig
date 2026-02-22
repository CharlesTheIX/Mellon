const std = @import("std");
const rl = @import("raylib");
const Map = @import("./lib/map.zig").Map;
const Dev = @import("./lib/.dev.zig").Dev;
const Timer = @import("./lib/timer.zig").Timer;
const Canvas = @import("./lib/canvas.zig").Canvas;
const Camera = @import("./lib/camera.zig").Camera;
const Key = @import("./lib/input-handler.zig").Key;
const IH = @import("./lib/input-handler.zig").InputHandler;

pub const NaseLaska = struct {
    ih: IH,
    map: Map,
    canvas: Canvas,
    camera: Camera,

    timer: Timer,

    // Static Methods
    pub fn init(allocator: std.mem.Allocator) NaseLaska {
        const ih = IH.init(allocator);
        var canvas = Canvas.init(800, 600);
        const camera = Camera.init(&canvas.rect);
        const map = Map.init(allocator);
        return NaseLaska{
            .map = map,
            .ih = ih,
            .canvas = canvas,
            .camera = camera,

            .timer = Timer.init(1000_000_000), // 1 second in nanoseconds
        };
    }

    // Instance Methods
    pub fn deinit(self: *NaseLaska) void {
        self.ih.deinit();
        self.map.deinit();
        self.camera.deinit();
        self.canvas.deinit();
    }

    fn draw(self: *NaseLaska) void {
        rl.beginMode2D(self.camera.camera);
        self.map.drawWorld();
        rl.endMode2D();
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
        // self.camera.update(&self.ih);
        self.camera.update();
        self.map.update();
    }
};
