const rl = @import("raylib");
const Canvas = @import("./canvas.zig").Canvas;
const Key = @import("./input-handler.zig").Key;
const NaseLaska = @import("../root.zig").NaseLaska;
const IH = @import("./input-handler.zig").InputHandler;

pub const MainMenu = struct {
    // Static Methods
    pub fn init() MainMenu {
        return MainMenu{};
    }

    // Instance Methods
    fn contentAreaPadding(canvas: *Canvas) i32 {
        return @as(i32, @intFromFloat(canvas.*.rect.width * 0.1));
    }

    pub fn deinit(self: *MainMenu) void {
        _ = self;
    }

    fn drawBackground(canvas: *Canvas) void {
        canvas.drawRect(
            0,
            0,
            @as(i32, @intFromFloat(canvas.*.rect.width)),
            @as(i32, @intFromFloat(canvas.*.rect.height)),
            rl.Color.dark_green.alpha(0.5),
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

    fn drawContent(self: *MainMenu, canvas: *Canvas) void {
        _ = self;
        // Draw in the centre of the content area
        const content_x = contentAreaPadding(canvas);
        const content_y = contentAreaPadding(canvas);
        const content_width = @as(i32, @intFromFloat(canvas.*.rect.width - 2 * @as(f32, @floatFromInt(contentAreaPadding(canvas)))));
        const content_height = @as(i32, @intFromFloat(canvas.*.rect.height - 2 * @as(f32, @floatFromInt(contentAreaPadding(canvas)))));
        const centre_x = content_x + @divFloor(content_width, 2);
        const centre_y = content_y + @divFloor(content_height, 2);
        const text = "Press Enter to Start";
        const text_width = rl.measureText(text, canvas.font_size);
        canvas.drawText(
            text,
            @as(i32, centre_x - @divFloor(text_width, 2)),
            @as(i32, centre_y - @divFloor(canvas.font_size, 2)),
            rl.Color.black,
        );
    }
    pub fn draw(self: *MainMenu, game: *NaseLaska) void {
        drawBackground(&game.canvas);
        drawContentArea(&game.canvas);
        self.drawContent(&game.canvas);
    }

    pub fn update(self: *MainMenu, game: *NaseLaska) void {
        _ = self;
        if (game.ih.keysActive(&[_]Key{.Enter}, .Or)) return game.new();
    }
};
