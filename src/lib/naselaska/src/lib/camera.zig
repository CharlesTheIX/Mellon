const std = @import("std");
const rl = @import("raylib");
const Key = @import("./input-handler.zig").Key;
const IH = @import("./input-handler.zig").InputHandler;

pub const Camera = struct {
    camera: rl.Camera2D,
    min_zoom: f32 = 0.1,
    max_zoom: f32 = 5.0,
    pan_speed: f32 = 5.0,
    zoom_speed: f32 = 0.1,
    target_zoom: f32 = 1.0,
    pan_lerp_speed: f32 = 0.1,
    target_position: rl.Vector2,

    pub fn init(canvas_rect: *rl.Rectangle) Camera {
        return .{
            .target_zoom = 1.0,
            .target_position = rl.Vector2.zero(),
            .camera = rl.Camera2D{
                .zoom = 1.0,
                .rotation = 0.0,
                .target = rl.Vector2.zero(),
                .offset = rl.Vector2.init(canvas_rect.width, canvas_rect.height).scale(0.5),
            },
        };
    }

    pub fn update(self: *Camera) void {
        if (self.camera.zoom != self.target_zoom) {
            const diff = self.target_zoom - self.camera.zoom;
            const step = std.math.sign(diff) * self.zoom_speed;
            if (@abs(diff) < @abs(step)) self.camera.zoom = self.target_zoom else self.camera.zoom += step;
        }

        self.camera.target = self.camera.target.lerp(self.target_position, self.pan_lerp_speed);
    }

    pub fn deinit(self: *Camera) void {
        _ = self;
    }

    pub fn getRect(self: *Camera, canvas_rect: *rl.Rectangle) rl.Rectangle {
        const view_width = canvas_rect.width / self.camera.zoom;
        const view_height = canvas_rect.height / self.camera.zoom;
        return rl.Rectangle{
            .width = view_width,
            .height = view_height,
            .x = self.camera.target.x - view_width / 2.0,
            .y = self.camera.target.y - view_height / 2.0,
        };
    }

    pub fn setPosition(self: *Camera, v: rl.Vector2) void {
        self.target_position = v;
    }

    pub fn getPosition(self: *Camera) rl.Vector2 {
        return self.camera.target;
    }

    pub fn getTargetPosition(self: *Camera) rl.Vector2 {
        return self.target_position;
    }

    pub fn setZoom(self: *Camera, zoom: f32) void {
        self.target_zoom = std.math.clamp(zoom, self.min_zoom, self.max_zoom);
    }

    pub fn getZoom(self: *Camera) f32 {
        return self.camera.zoom;
    }

    pub fn zoomIn(self: *Camera) void {
        self.setZoom(self.target_zoom + self.zoom_speed);
    }

    pub fn zoomOut(self: *Camera) void {
        self.setZoom(self.target_zoom - self.zoom_speed);
    }

    pub fn setRotation(self: *Camera, degrees: f32) void {
        self.camera.rotation = degrees;
    }

    pub fn getRotation(self: *Camera) f32 {
        return self.camera.rotation;
    }

    pub fn rotate(self: *Camera, degrees: f32) void {
        self.camera.rotation += degrees;
        // Keep rotation in 0-360 range
        while (self.camera.rotation >= 360.0) self.camera.rotation -= 360.0;
        while (self.camera.rotation < 0.0) self.camera.rotation += 360.0;
    }

    pub fn worldToScreen(self: *Camera, world_pos: rl.Vector2) rl.Vector2 {
        return rl.getScreenToWorld2D(world_pos, self.camera);
    }

    pub fn screenToWorld(self: *Camera, screen_pos: rl.Vector2) rl.Vector2 {
        return rl.getScreenToWorld2D(screen_pos, self.camera);
    }

    pub fn focusOn(self: *Camera, x: f32, y: f32) void {
        self.target_position = rl.Vector2{ .x = x, .y = y };
    }

    pub fn getRayLibCamera(self: *Camera) rl.Camera2D {
        return self.camera;
    }

    pub fn reset(self: *Camera, x: f32, y: f32) void {
        const pos = rl.Vector2{ .x = x, .y = y };
        self.camera.target = pos;
        self.target_position = pos;
        self.camera.rotation = 0.0;
        self.camera.zoom = 1.0;
        self.target_zoom = 1.0;
    }

    pub fn constrainToBounds(self: *Camera, world_width: f32, world_height: f32) void {
        const view_width = 800.0 / self.camera.zoom;
        const view_height = 600.0 / self.camera.zoom;

        self.camera.target.x = std.math.clamp(
            self.camera.target.x,
            view_width / 2.0,
            world_width - view_width / 2.0,
        );
        self.camera.target.y = std.math.clamp(
            self.camera.target.y,
            view_height / 2.0,
            world_height - view_height / 2.0,
        );
    }
};
