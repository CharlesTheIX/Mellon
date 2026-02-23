const std = @import("std");
const Timer = @import("./timer.zig").Timer;

pub const Dev = struct {
    show_ih: bool = false,
    show_map: bool = false,
    show_camera: bool = false,
    timer: Timer = Timer.init(500_000_000),

    pub fn init() Dev {
        return Dev{};
    }

    pub fn deinit(self: *Dev) void {
        _ = self;
    }

    pub fn draw(self: *Dev) void {
        if (self.show_map) std.debug.print("Map Debug Info\n", .{});
        if (self.show_camera) std.debug.print("Camera Debug Info\n", .{});
        if (self.show_ih) std.debug.print("Input Handler Debug Info\n", .{});
    }

    pub fn update(self: *Dev) void {
        _ = self;
    }
};
