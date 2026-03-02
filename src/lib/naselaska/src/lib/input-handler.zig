const std = @import("std");
const rl = @import("raylib");
const Camera = @import("./camera.zig").Camera;

pub const InputHandler = struct {
    allocator: std.mem.Allocator,
    active_keys: std.AutoHashMap(Key, void),
    active_clicks: std.AutoHashMap(Click, void),

    // Static Methods
    pub fn init(allocator: std.mem.Allocator) InputHandler {
        const active_keys = std.AutoHashMap(Key, void).init(allocator);
        const active_clicks = std.AutoHashMap(Click, void).init(allocator);
        return .{
            .allocator = allocator,
            .active_keys = active_keys,
            .active_clicks = active_clicks,
        };
    }

    // Instance Methods
    pub fn clicksActive(self: *InputHandler, clicks: []const Click, filter: enum { And, Or }) bool {
        switch (filter) {
            .And => {
                for (clicks) |click| {
                    if (self.active_clicks.get(click) == null) return false;
                }
                return true;
            },
            .Or => {
                for (clicks) |click| {
                    if (self.active_clicks.get(click) != null) return true;
                }
                return false;
            },
        }
    }

    pub fn deinit(self: *InputHandler) void {
        self.active_keys.deinit();
        self.active_clicks.deinit();
    }

    pub fn keysActive(self: *InputHandler, keys: []const Key, filter: enum { And, Or }) bool {
        switch (filter) {
            .And => {
                for (keys) |key| {
                    if (self.active_keys.get(key) == null) return false;
                }
                return true;
            },
            .Or => {
                for (keys) |key| {
                    if (self.active_keys.get(key) != null) return true;
                }
                return false;
            },
        }
    }

    pub fn mouseScreenPos(self: *InputHandler) rl.Vector2 {
        _ = self; // Avoid unused parameter warning
        return rl.getMousePosition();
    }

    pub fn mouseWorldPos(self: *InputHandler, camera: *Camera) rl.Vector2 {
        const mouse_screen_pos = self.mouseScreenPos();
        return rl.getScreenToWorld2D(mouse_screen_pos, camera.camera);
    }


    pub fn update(self: *InputHandler) void {
        self.active_keys.clearRetainingCapacity();
        for (Key.array()) |key| {
            if (rl.isKeyDown(key.toKeyboardKey())) _ = self.active_keys.put(key, {}) catch {};
        }

        self.active_clicks.clearRetainingCapacity();
        for (Click.array()) |click| {
            if (rl.isMouseButtonDown(click.toMouseButton())) _ = self.active_clicks.put(click, {}) catch {};
        }
    }
};

pub const Click = enum {
    Left,
    Right,
    Middle,

    pub fn array() []const Click {
        return &[_]Click{ .Left, .Right, .Middle };
    }

    pub fn toMouseButton(self: Click) rl.MouseButton {
        return switch (self) {
            .Left => rl.MouseButton.left,
            .Right => rl.MouseButton.right,
            .Middle => rl.MouseButton.middle,
        };
    }

    pub fn toString(self: Click) []const u8 {
        return switch (self) {
            .Left => "Left",
            .Right => "Right",
            .Middle => "Middle",
        };
    }
};

pub const Key = enum {
    W,
    A,
    S,
    D,
    Up,
    Down,
    Left,
    Right,
    Space,
    Enter,
    Escape,
    LeftAlt,
    RightAlt,
    LeftShift,
    RightShift,
    LeftControl,
    RightControl,
    One,
    Two,
    Three,
    Four,
    Five,
    Six,
    Seven,
    Eight,
    Nine,
    Zero,

    pub fn array() []const Key {
        return &[_]Key{
            .One,    .Two,       .Three,      .Four,        .Five,         .Six,     .Seven,    .Eight, .Nine,  .Zero,
            .W,      .A,         .S,          .D,           .Up,           .Down,    .Left,     .Right, .Space, .Enter,
            .Escape, .LeftShift, .RightShift, .LeftControl, .RightControl, .LeftAlt, .RightAlt,
        };
    }

    pub fn toKeyboardKey(self: Key) rl.KeyboardKey {
        return switch (self) {
            .One => rl.KeyboardKey.one,
            .Two => rl.KeyboardKey.two,
            .Three => rl.KeyboardKey.three,
            .Four => rl.KeyboardKey.four,
            .Five => rl.KeyboardKey.five,
            .Six => rl.KeyboardKey.six,
            .Seven => rl.KeyboardKey.seven,
            .Eight => rl.KeyboardKey.eight,
            .Nine => rl.KeyboardKey.nine,
            .Zero => rl.KeyboardKey.zero,
            .W => rl.KeyboardKey.w,
            .A => rl.KeyboardKey.a,
            .S => rl.KeyboardKey.s,
            .D => rl.KeyboardKey.d,
            .Up => rl.KeyboardKey.up,
            .Down => rl.KeyboardKey.down,
            .Left => rl.KeyboardKey.left,
            .Right => rl.KeyboardKey.right,
            .Space => rl.KeyboardKey.space,
            .Enter => rl.KeyboardKey.enter,
            .Escape => rl.KeyboardKey.escape,
            .LeftAlt => rl.KeyboardKey.left_alt,
            .RightAlt => rl.KeyboardKey.right_alt,
            .LeftShift => rl.KeyboardKey.left_shift,
            .RightShift => rl.KeyboardKey.right_shift,
            .LeftControl => rl.KeyboardKey.left_control,
            .RightControl => rl.KeyboardKey.right_control,
        };
    }

    pub fn toString(self: Key) []const u8 {
        return switch (self) {
            .One => "1",
            .Two => "2",
            .Three => "3",
            .Four => "4",
            .Five => "5",
            .Six => "6",
            .Seven => "7",
            .Eight => "8",
            .Nine => "9",
            .Zero => "0",
            .W => "W",
            .A => "A",
            .S => "S",
            .D => "D",
            .Up => "Up",
            .Down => "Down",
            .Left => "Left",
            .Right => "Right",
            .Space => "Space",
            .Enter => "Enter",
            .Escape => "Escape",
            .LeftAlt => "LeftAlt",
            .RightAlt => "RightAlt",
            .LeftShift => "LeftShift",
            .RightShift => "RightShift",
            .LeftControl => "LeftControl",
            .RightControl => "RightControl",
        };
    }
};
