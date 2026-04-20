const std = @import("std");
const rl = @import("raylib");
const Filter = @import("./utils.zig").Filter;

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

pub const Mouse = struct {
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
