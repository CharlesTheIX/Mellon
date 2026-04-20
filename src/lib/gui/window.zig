const std = @import("std");
const rl = @import("raylib");

const WindowInitSize = enum { Default };

pub const Window = struct {
    width: i32,
    height: i32,
    title: [:0]const u8,

    pub fn init(title: [:0]const u8, init_size: WindowInitSize) Window {
        switch (init_size) {
            .Default => return .{ .width = 1200, .height = 800, .title = title },
        }
    }

    pub fn deinit(self: *Window) void {
        _ = self;
        // No resources to free
    }

    // . -------------------------------------------------------------------------
    pub fn asRectangle(self: *Window) rl.Rectangle {
        return rl.Rectangle{
            .x = 0,
            .y = 0,
            .width = @as(f32, @floatFromInt(self.width)),
            .height = @as(f32, @floatFromInt(self.height)),
        };
    }

    pub fn asVector2(self: *Window) rl.Vector2 {
        return rl.Vector2{
            .x = @as(f32, @floatFromInt(self.width)),
            .y = @as(f32, @floatFromInt(self.height)),
        };
    }

    pub fn resize(self: *Window) void {
        self.width = rl.getScreenWidth();
        self.height = rl.getScreenHeight();
    }
};
