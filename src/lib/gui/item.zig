const rl = @import("raylib");
const Color = @import("./canvas.zig").Color;
const Canvas = @import("./canvas.zig").Canvas;
const Key = @import("./input_handler/root.zig").Key;
const InputHandler = @import("./input_handler/root.zig").InputHandler;

const ItemState = enum { Normal, Hovered, Selected };
pub const Item = struct {
    rect: rl.Rectangle,
    rotation: f32 = 0.0,
    input_timer: f32 = 0.0,
    input_timeout: f32 = 0.2,
    state: ?ItemState = null,
    color: Color = Color.Green,

    pub fn init(tiles: [2]u8) Item {
        return Item{
            .rect = rl.Rectangle{
                .x = 0,
                .y = 0,
                .width = tiles[0] * 16,
                .height = tiles[1] * 16,
            },
        };
    }

    pub fn update(self: *Item, input_handler: *InputHandler, camera: *rl.Camera2D) void {
        if (self.state == null) {
            self.updateRotation(input_handler);
            const mouse_pos = input_handler.mouse.v2_camera(camera);
            self.rect.x = mouse_pos.x - self.rect.width / 2;
            self.rect.y = mouse_pos.y - self.rect.height / 2;
            const grid_size = 16.0;
            self.rect.x = @round(self.rect.x / grid_size) * grid_size;
            self.rect.y = @round(self.rect.y / grid_size) * grid_size;
            if (input_handler.mouse.active_clicks.contains(.Left)) self.place();
        }
    }

    pub fn place(self: *Item) void {
        self.state = .Normal;
        self.input_timeout = 0.2; // reset input timeout after placing
        self.input_timer = self.input_timeout; // start input timer to prevent immediate rotation after placing
    }

    pub fn updateRotation(self: *Item, input_handler: *InputHandler) void {
        if (self.input_timer > 0) {
            self.input_timer -= rl.getFrameTime();
            return;
        }
        if (!input_handler.keys.contains(&[_]Key{.Space}, .Or)) return;
        self.rotation = @mod(self.rotation + 90, 360);
        self.input_timer = self.input_timeout; // debounce input
    }

    pub fn draw(self: *Item, canvas: *Canvas) void {
        canvas.drawRect(self.rect, self.color.toRL(80));
    }
};
