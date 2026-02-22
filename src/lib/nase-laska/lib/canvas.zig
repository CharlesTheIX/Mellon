const rl = @import("raylib");

pub const Canvas = struct {
    rect: rl.Rectangle,

    // Static Methods
    pub fn init(width: f32, height: f32) Canvas {
        const rect = rl.Rectangle{ .x = 0, .y = 0, .width = width, .height = height };
        return Canvas{ .rect = rect };
    }

    // Instance Methods
    pub fn deinit(self: *Canvas) void {
        _ = self;
    }
};
