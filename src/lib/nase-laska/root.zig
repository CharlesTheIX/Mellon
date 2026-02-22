const std = @import("std");
const rl = @import("raylib");
const Map = @import("./map.zig").Map;
const IO = @import("../core/io.zig").IO;
const Canvas = @import("./canvas.zig").Canvas;
const Config = @import("../core/config.zig").Config;
const IH = @import("./input-handler.zig").InputHandler;
const FS = @import("../core/file-system.zig").FileSystem;

pub const NaseLaska = struct {
    fs: FS,
    io: IO,
    ih: IH,
    map: Map,
    canvas: Canvas,
    config: Config,

    // Static Methods
    pub fn init(allocator: std.mem.Allocator) NaseLaska {
        var stdin_buffer: [1024]u8 = undefined;
        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        var stdin_reader = std.fs.File.stdin().readerStreaming(&stdin_buffer);

        var config = Config.init(allocator);
        const ih = IH.init(allocator);
        const canvas = Canvas.init(800, 600);
        var io = IO.init(allocator, &stdin_reader, &stdout_writer, &config);
        var fs = FS.init(&io, &config);
        const map = Map.init(&fs);
        return NaseLaska{
            .io = io,
            .map = map,
            .fs = fs,
            .ih = ih,
            .canvas = canvas,
            .config = config,
        };
    }

    // Instance Methods
    pub fn deinit(self: *NaseLaska) void {
        self.fs.deinit();
        self.ih.deinit();
        self.io.deinit();
        self.canvas.deinit();
        self.config.deinit();
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
        self.map.update();
    }
};
