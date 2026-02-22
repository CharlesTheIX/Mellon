const std = @import("std");
const rl = @import("raylib");

pub const InputHandler = struct {
    allocator: std.mem.Allocator,
    active_keys: std.AutoHashMap(Key, void),

    // Static Methods
    pub fn init(allocator: std.mem.Allocator) InputHandler {
        const active_keys = std.AutoHashMap(Key, void).init(allocator);
        return .{ .allocator = allocator, .active_keys = active_keys };
    }

    // Instance Methods
    pub fn deinit(self: *InputHandler) void {
        self.active_keys.deinit();
    }

    pub fn draw(self: *InputHandler) void {
        // Build comma-separated string of active keys
        var pos: usize = 0;
        var buffer: [256]u8 = undefined;
        var iter = self.active_keys.iterator();
        while (iter.next()) |key| {
            const name = Key.toString(key.key_ptr.*);
            if (pos > 0 and pos < buffer.len) {
                buffer[pos] = ',';
                pos += 1;
            }
            const name_len = name.len;
            if (pos + name_len < buffer.len) {
                @memcpy(buffer[pos..][0..name_len], name);
                pos += name_len;
            }
        }

        // Ensure null-termination
        if (pos < buffer.len) buffer[pos] = 0;

        rl.drawText("Active Keys:", 10, 10, 16, rl.Color.white);
        const str: [:0]const u8 = buffer[0..pos :0];
        rl.drawText(str, 10, 40, 16, rl.Color.white);
    }

    pub fn keysActive(self: *InputHandler, keys: []const Key, filter: enum { And, Or }) bool {
        for (keys) |key| {
            if (self.active_keys.get(key) == null) return filter == .Or;
        }
        return filter == .And;
    }

    pub fn update(self: *InputHandler) void {
        self.active_keys.clearRetainingCapacity();
        for (Key.array()) |key| {
            if (rl.isKeyDown(key.toKeyboardKey())) _ = self.active_keys.put(key, {}) catch {};
        }
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

    pub fn toString(self: Key) []const u8 {
        return switch (self) {
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

    pub fn toKeyboardKey(self: Key) rl.KeyboardKey {
        return switch (self) {
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

    pub fn array() []const Key {
        return &[_]Key{
            .W,        .A,     .S,      .D,         .Up,         .Down,        .Left,         .Right,
            .Space,    .Enter, .Escape, .LeftShift, .RightShift, .LeftControl, .RightControl, .LeftAlt,
            .RightAlt,
        };
    }
};
