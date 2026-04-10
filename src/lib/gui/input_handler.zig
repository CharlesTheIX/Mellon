const std = @import("std");
const rl = @import("raylib");
const Camera = @import("./camera.zig").Camera;

pub const InputHandler = struct {
    keys: Keys,
    mouse: Mouse,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) InputHandler {
        return .{
            .allocator = allocator,
            .keys = Keys.init(allocator),
            .mouse = Mouse.init(allocator),
        };
    }

    pub fn deinit(self: *InputHandler) void {
        self.keys.deinit();
        self.mouse.deinit();
    }

    // . -------------------------------------------------------------------------
    pub fn update(self: *InputHandler) void {
        self.keys.update();
        self.mouse.update();
    }

    // KEYS -------------------------------------------------------------------------
    pub fn keyPressed(self: *InputHandler, key: Key) bool {
        _ = self;
        return rl.isKeyPressed(key.toKeyboardKey());
    }

    pub fn keysActive(self: *InputHandler, keys: []const Key, filter: Filter) bool {
        return self.keys.contains(keys, filter);
    }

    pub fn mostRecentActiveKey(self: *InputHandler, keys: []const Key) ?Key {
        return self.keys.mostRecent(keys);
    }

    // MOUSE -------------------------------------------------------------------------
    pub fn clicksActive(self: *InputHandler, clicks: []const Click, filter: Filter) bool {
        return self.mouse.clicksContains(clicks, filter);
    }

    pub fn mouseCameraPosition(self: *InputHandler, camera: *Camera) rl.Vector2 {
        return self.mouse.v2_camera(&camera.camera);
    }

    pub fn mouseWindowPosition(self: *InputHandler) rl.Vector2 {
        return self.mouse.v2_window();
    }
};

const Mouse = struct {
    cursor: Cursor = .Default,
    active_clicks: std.AutoHashMap(Click, void),

    pub fn init(allocator: std.mem.Allocator) Mouse {
        const active_clicks = std.AutoHashMap(Click, void).init(allocator);
        return Mouse{
            .active_clicks = active_clicks,
        };
    }

    pub fn deinit(self: *Mouse) void {
        self.active_clicks.deinit();
    }

    // . -------------------------------------------------------------------------
    pub fn clicksContains(self: *Mouse, clicks: []const Click, filter: Filter) bool {
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

    pub fn update(self: *Mouse) void {
        self.active_clicks.clearRetainingCapacity();
        for (Click.array()) |click| {
            if (rl.isMouseButtonDown(click.toRL())) _ = self.active_clicks.put(click, {}) catch {};
        }

        const _scroll = self.scroll();
        std.debug.print("scroll V2: {} {}\n", .{ _scroll.x, _scroll.y });
    }

    // CURSOR -----------------------------------------------------------------------
    pub fn setCursor(self: *Mouse, cursor: Cursor) void {
        _ = self;
        rl.setMouseCursor(cursor.toRL());
    }

    pub fn showCursor(self: *Mouse) void {
        _ = self;
        rl.showCursor();
    }

    pub fn hideCursor(self: *Mouse) void {
        _ = self;
        rl.hideCursor();
    }

    // SCROLL -----------------------------------------------------------------------
    pub fn scroll(self: *Mouse) rl.Vector2 {
        _ = self;
        return rl.getMouseWheelMoveV();
    }

    // VECTORS -----------------------------------------------------------------------
    pub fn v2_camera(self: *Mouse, camera: *rl.Camera2D) rl.Vector2 {
        _ = self;
        return rl.getScreenToWorld2D(rl.getMousePosition(), camera.*);
    }

    pub fn v2_window(self: *Mouse) rl.Vector2 {
        _ = self;
        return rl.getMousePosition();
    }
};

const Keys = struct {
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

pub const Cursor = enum {
    Arrow,
    Ibeam,
    Default,
    ResizeEW,
    ResizeNS,
    Crosshair,
    ResizeALL,
    ResizeNWSE,
    ResizeNESW,
    NotAllowed,
    PointingHand,

    pub fn toRL(self: Cursor) rl.MouseCursor {
        return switch (self) {
            .Arrow => .arrow,
            .Ibeam => .ibeam,
            .Default => .default,
            .ResizeEW => .resize_ew,
            .ResizeNS => .resize_ns,
            .Crosshair => .crosshair,
            .ResizeALL => .resize_all,
            .ResizeNWSE => .resize_nwse,
            .ResizeNESW => .resize_nesw,
            .NotAllowed => .not_allowed,
            .PointingHand => .pointing_hand,
        };
    }
};

const Filter = enum { And, Or };

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
