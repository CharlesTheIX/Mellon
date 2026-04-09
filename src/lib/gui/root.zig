const std = @import("std");
const rl = @import("raylib");
const Camera = @import("./camera.zig").Camera;
const Canvas = @import("./canvas.zig").Canvas;
const Window = @import("./window.zig").Window;
const InputHandler = @import("./input_handler.zig").InputHandler;

pub const Gui = struct {
    camera: Camera,
    canvas: Canvas,
    window: Window,
    input_handler: InputHandler,

    pub fn init(allocator: std.mem.Allocator) Gui {
        var window = Window.init("Mellon GUI", .Default);
        return .{
            .window = window,
            .camera = Camera.init(&window),
            .canvas = Canvas.init(&window),
            .input_handler = InputHandler.init(allocator),
        };
    }

    pub fn deinit(self: *Gui) void {
        self.camera.deinit();
        self.canvas.deinit();
        self.window.deinit();
        self.input_handler.deinit();
    }

    // . -------------------------------------------------------------------------
    pub fn load(self: *Gui) void {
        self.canvas.load();
    }

    pub fn run(self: *Gui) void {
        rl.setTargetFPS(60);
        rl.setConfigFlags(rl.ConfigFlags{ .window_resizable = true, .vsync_hint = true });
        rl.initWindow(self.window.width, self.window.height, self.window.title);
        defer rl.closeWindow();
        self.load();
        while (!rl.windowShouldClose()) {
            self.update();
            self.draw();
        }
    }

    // DRAW -------------------------------------------------------------------------
    fn draw(self: *Gui) void {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);
        self.drawMain();
        self.drawPeripheries();
        rl.endDrawing();
    }

    fn drawMain(self: *Gui) void {
        rl.beginMode2D(self.camera.camera);
        self.canvas.drawGrid();
        rl.endMode2D();
    }

    fn drawPeripheries(self: *Gui) void {
        self.canvas.drawWindowGrid(&self.window);
    }

    // UPDATE -------------------------------------------------------------------------
    fn update(self: *Gui) void {
        if (rl.isWindowResized()) self.updateResize();
        self.input_handler.update();
        self.camera.update(&self.input_handler);
        std.debug.print("Camera Target: ({}, {})\n", .{ self.camera.camera.target.x, self.camera.camera.target.y });
    }

    fn updateResize(self: *Gui) void {
        self.window.resize();
        self.canvas.resize(self.window.asRectangle());
        self.camera.resize(self.window.asVector2().scale(0.5));
    }
};
