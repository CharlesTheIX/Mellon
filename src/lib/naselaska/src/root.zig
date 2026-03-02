const std = @import("std");
const rl = @import("raylib");
const Map = @import("./lib/map.zig").Map;
const Dev = @import("./lib/.dev/root.zig").Dev;
const Canvas = @import("./lib/canvas.zig").Canvas;
const Camera = @import("./lib/camera.zig").Camera;
const Player = @import("./lib/player.zig").Player;
const Key = @import("./lib/input-handler.zig").Key;
const MainMenu = @import("./lib/main-menu.zig").MainMenu;
const IH = @import("./lib/input-handler.zig").InputHandler;
const AH = @import("./lib/audio-handler.zig").AudioHandler;

pub const NaseLaska = struct {
    ih: IH,
    map: Map,
    canvas: Canvas,
    camera: Camera,
    sfx_player: AH,
    player: Player,
    music_player: AH,
    main_menu: MainMenu,
    state: State = .MainMenu,
    prev_state: State = .MainMenu,
    dev: Dev,

    // Static Methods
    pub fn init(allocator: std.mem.Allocator) NaseLaska {
        var canvas = Canvas.init(800, 592);
        return NaseLaska{
            .canvas = canvas,
            .map = Map.init(allocator),
            .ih = IH.init(allocator),
            .main_menu = MainMenu.init(),
            .camera = Camera.init(&canvas.rect),
            .player = Player.init("Test Player"),
            .sfx_player = AH.init(allocator),
            .music_player = AH.init(allocator),
            .dev = Dev.init(),
        };
    }

    // Instance Methods
    pub fn deinit(self: *NaseLaska) void {
        self.dev.deinit();

        self.ih.deinit();
        self.map.deinit();
        self.camera.deinit();
        self.canvas.deinit();
        self.main_menu.deinit();
    }

    fn draw(self: *NaseLaska) void {
        switch (self.state) {
            .MainMenu => self.main_menu.draw(self),
            .Playing => {
                rl.beginMode2D(self.camera.camera);
                self.map.draw();
                rl.endMode2D();
            },
            .Settings => {
                // Draw settings menu here
            },
        }

        self.dev.draw(
            &self.ih,
            &self.camera,
            &self.map,
            &self.canvas,
            &self.music_player,
            &self.sfx_player,
        );
    }

    pub fn run(self: *NaseLaska) void {
        rl.setConfigFlags(rl.ConfigFlags{ .window_resizable = true });
        rl.setTargetFPS(60);
        rl.initWindow(@intFromFloat(self.canvas.rect.width), @intFromFloat(self.canvas.rect.height), "Naše Láska");
        defer rl.closeWindow();

        self.canvas.load("./data/fonts/JetBrains.ttf");

        while (!rl.windowShouldClose()) {
            if (rl.isWindowResized()) self.canvas.handleResize(&self.camera);
            rl.beginDrawing();
            rl.clearBackground(rl.Color.black);
            self.update();
            self.draw();
            rl.endDrawing();
        }
        return std.process.exit(0);
    }

    pub fn new(self: *NaseLaska) void {
        self.map.load("test");
        self.state = .Playing;
        _ = self.music_player.load(.Music, "test_1", "./data/audio/music/test_1.wav") catch return;
        _ = self.music_player.play(.Music, "test");
    }

    pub fn settings(self: *NaseLaska) void {
        self.state = .Settings;
        self.prev_state = self.state;
    }

    pub fn mainMenu(self: *NaseLaska) void {
        self.state = .MainMenu;
        self.prev_state = .MainMenu;
    }

    fn update(self: *NaseLaska) void {
        self.ih.update();
        if (self.ih.keysActive(&[_]Key{ .LeftShift, .RightShift }, .Or) and self.ih.keysActive(&[_]Key{.S}, .And)) {
            self.settings();
        }

        switch (self.state) {
            .MainMenu => self.main_menu.update(self),
            .Playing => {
                self.camera.update();
                self.map.update();
            },
            .Settings => {},
        }

        self.music_player.updateMusicStreams();
        self.dev.update(&self.ih);
    }
};

pub const State = enum {
    MainMenu,
    Playing,
    Settings,
};
