const std = @import("std");
const rl = @import("raylib");
const Camera = @import("./camera.zig").Camera;

pub const InputHandler = struct {
    next_key_order: u64,
    allocator: std.mem.Allocator,
    active_keys: std.AutoHashMap(Key, void),
    key_press_order: std.AutoHashMap(Key, u64),
    active_clicks: std.AutoHashMap(Click, void),

    pub fn init(allocator: std.mem.Allocator) InputHandler {
        const active_keys = std.AutoHashMap(Key, void).init(allocator);
        const key_press_order = std.AutoHashMap(Key, u64).init(allocator);
        const active_clicks = std.AutoHashMap(Click, void).init(allocator);
        return .{
            .next_key_order = 1,
            .allocator = allocator,
            .active_keys = active_keys,
            .key_press_order = key_press_order,
            .active_clicks = active_clicks,
        };
    }

    pub fn deinit(self: *InputHandler) void {
        self.active_keys.deinit();
        self.active_clicks.deinit();
        self.key_press_order.deinit();
    }

    // . -------------------------------------------------------------------------
    pub fn update(self: *InputHandler) void {
        for (Key.array()) |key| {
            const is_down = rl.isKeyDown(key.toRL());
            const was_down = self.active_keys.get(key) != null;
            if (is_down) {
                if (!was_down) {
                    _ = self.key_press_order.put(key, self.next_key_order) catch {};
                    self.next_key_order += 1;
                }
                _ = self.active_keys.put(key, {}) catch {};
            } else if (was_down) {
                _ = self.active_keys.remove(key);
                _ = self.key_press_order.remove(key);
            }
        }

        self.active_clicks.clearRetainingCapacity();
        for (Click.array()) |click| {
            if (rl.isMouseButtonDown(click.toRL())) _ = self.active_clicks.put(click, {}) catch {};
        }
    }

    // KEYS -------------------------------------------------------------------------
    pub fn keyPressed(self: *InputHandler, key: Key) bool {
        _ = self; // Avoid unused parameter warning
        return rl.isKeyPressed(key.toKeyboardKey());
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

    pub fn mostRecentActiveKey(self: *InputHandler, keys: []const Key) ?Key {
        var newest_order: u64 = 0;
        var newest_key: ?Key = null;
        for (keys) |key| {
            if (self.key_press_order.get(key)) |order| {
                if (order > newest_order) {
                    newest_key = key;
                    newest_order = order;
                }
            }
        }
        return newest_key;
    }

    // MOUSE -------------------------------------------------------------------------
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

    pub fn mouseCameraPosition(self: *InputHandler, camera: *Camera) rl.Vector2 {
        _ = self;
        return rl.getScreenToWorld2D(rl.getMousePosition(), camera.camera);
    }

    pub fn mouseWindowPosition(self: *InputHandler) rl.Vector2 {
        _ = self;
        return rl.getMousePosition();
    }
};

pub const Click = enum {
    Left,
    Right,
    Middle,

    // . -------------------------------------------------------------------------
    pub fn array() []const Click {
        return &[_]Click{ .Left, .Right, .Middle };
    }

    pub fn toRL(self: Click) rl.MouseButton {
        return switch (self) {
            .Left => rl.MouseButton.left,
            .Right => rl.MouseButton.right,
            .Middle => rl.MouseButton.middle,
        };
    }
};

pub const Key = enum {
    // Movement
    W,
    A,
    S,
    D,
    Up,
    Down,
    Left,
    Right,
    // Actions
    Space,
    Enter,
    Equal, // Zoom in (with LeftShift or RightShift)
    Minus, // Zoom out
    P, // Pause
    // Esc
    Escape,
    // Modifiers
    LeftAlt,
    RightAlt,
    LeftShift,
    RightShift,
    LeftControl,
    RightControl,
    // Numbers
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

    // . -------------------------------------------------------------------------
    pub fn array() []const Key {
        return &[_]Key{ .One, .Two, .Three, .Four, .Five, .Six, .Seven, .Eight, .Nine, .Zero, .W, .A, .S, .D, .Up, .Down, .Left, .Right, .Space, .Enter, .Escape, .LeftShift, .RightShift, .LeftControl, .RightControl, .LeftAlt, .RightAlt, .Equal, .Minus, .P };
    }

    pub fn toRL(self: Key) rl.KeyboardKey {
        return switch (self) {
            // Movement
            .W => rl.KeyboardKey.w,
            .A => rl.KeyboardKey.a,
            .S => rl.KeyboardKey.s,
            .D => rl.KeyboardKey.d,
            .Up => rl.KeyboardKey.up,
            .Down => rl.KeyboardKey.down,
            .Left => rl.KeyboardKey.left,
            .Right => rl.KeyboardKey.right,
            // Actions
            .Space => rl.KeyboardKey.space,
            .Enter => rl.KeyboardKey.enter,
            .Equal => rl.KeyboardKey.equal, // Zoom in (with LeftShift or RightShift)
            .Minus => rl.KeyboardKey.minus, // Zoom out
            .P => rl.KeyboardKey.p, // Pause
            // Esc
            .Escape => rl.KeyboardKey.escape,
            // Modifiers
            .LeftAlt => rl.KeyboardKey.left_alt,
            .RightAlt => rl.KeyboardKey.right_alt,
            .LeftShift => rl.KeyboardKey.left_shift,
            .RightShift => rl.KeyboardKey.right_shift,
            .LeftControl => rl.KeyboardKey.left_control,
            .RightControl => rl.KeyboardKey.right_control,
            // Numbers
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
        };
    }
};
