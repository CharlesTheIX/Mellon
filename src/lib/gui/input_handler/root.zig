const std = @import("std");
const rl = @import("raylib");
const Camera = @import("../camera.zig").Camera;
const Click = @import("./lib/mouse.zig").Click;
const Mouse = @import("./lib/mouse.zig").Mouse;
const Filter = @import("./lib/utils.zig").Filter;

pub const Key = @import("./lib/keys.zig").Key;
pub const Keys = @import("./lib/keys.zig").Keys;

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
