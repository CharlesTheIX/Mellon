const std = @import("std");
const rl = @import("raylib");
const Filter = @import("./utils.zig").Filter;

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
    LeftBracket, // Rotate left (with LeftShift or RightShift)
    RightBracket, // Rotate right (with LeftShift or RightShift)
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
        return &[_]Key{ .One, .Two, .Three, .Four, .Five, .Six, .Seven, .Eight, .Nine, .Zero, .W, .A, .S, .D, .Up, .Down, .Left, .Right, .Space, .Enter, .Escape, .LeftShift, .RightShift, .LeftControl, .RightControl, .LeftAlt, .RightAlt, .Equal, .Minus, .LeftBracket, .RightBracket, .P };
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
            .LeftBracket => rl.KeyboardKey.left_bracket, // Rotate left (with LeftShift or RightShift)
            .RightBracket => rl.KeyboardKey.right_bracket, // Rotate right (with LeftShift or RightShift)
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

pub const Keys = struct {
    next_key_order: u64,
    active_keys: std.AutoHashMap(Key, void),
    key_press_order: std.AutoHashMap(Key, u64),

    pub fn init(allocator: std.mem.Allocator) Keys {
        const active_keys = std.AutoHashMap(Key, void).init(allocator);
        const key_press_order = std.AutoHashMap(Key, u64).init(allocator);
        return Keys{
            .next_key_order = 1,
            .active_keys = active_keys,
            .key_press_order = key_press_order,
        };
    }

    pub fn deinit(self: *Keys) void {
        self.next_key_order = 1;
        self.active_keys.deinit();
        self.key_press_order.deinit();
    }

    // . -------------------------------------------------------------------------
    pub fn contains(self: *Keys, keys: []const Key, filter: Filter) bool {
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

    pub fn indexOf(self: *Keys, key: Key) ?u64 {
        return self.key_press_order.get(key);
    }

    pub fn mostRecent(self: *Keys, keys: []const Key) ?Key {
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

    pub fn pressed(self: *Keys, key: Key) bool {
        _ = self;
        return rl.isKeyPressed(key.toRL());
    }

    pub fn update(self: *Keys) void {
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
    }
};
