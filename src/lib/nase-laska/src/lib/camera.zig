const std = @import("std");
const rl = @import("raylib");
const Key = @import("./input-handler.zig").Key;
const IH = @import("./input-handler.zig").InputHandler;

/// Camera2D wrapper for managing viewport and world transformations
pub const Camera = struct {
    camera: rl.Camera2D,
    min_zoom: f32 = 0.1,
    max_zoom: f32 = 5.0,
    pan_speed: f32 = 5.0,
    zoom_speed: f32 = 0.1,
    target_zoom: f32 = 1.0,
    pan_lerp_speed: f32 = 0.1, // Lerp speed toward target position (0.0 = no movement, 1.0 = instant)
    target_position: rl.Vector2,

    /// Initialize camera at position with default settings
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

    /// Update camera (smooth zoom and pan transitions)
    // pub fn update(self: *Camera, ih: *IH) void {
    pub fn update(self: *Camera) void {
        // Smooth zoom interpolation
        if (self.camera.zoom != self.target_zoom) {
            const diff = self.target_zoom - self.camera.zoom;
            const step = std.math.sign(diff) * self.zoom_speed;
            if (@abs(diff) < @abs(step)) self.camera.zoom = self.target_zoom else self.camera.zoom += step;
        }

        // if (ih.keysActive(&[_]Key{ .Left, .A }, .Or)) {
        //     self.target_position.x -= self.pan_speed / self.camera.zoom;
        //     std.debug.print("Left pressed\n", .{});
        // }
        // if (ih.keysActive(&[_]Key{ .Right, .D }, .Or)) self.target_position.x += self.pan_speed / self.camera.zoom;
        // if (ih.keysActive(&[_]Key{ .Up, .W }, .Or)) self.target_position.y -= self.pan_speed / self.camera.zoom;
        // if (ih.keysActive(&[_]Key{ .Down, .S }, .Or)) self.target_position.y += self.pan_speed / self.camera.zoom;
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

    /// Set target zoom level (animates smoothly)
    pub fn setZoom(self: *Camera, zoom: f32) void {
        self.target_zoom = std.math.clamp(zoom, self.min_zoom, self.max_zoom);
    }

    /// Get current zoom level
    pub fn getZoom(self: *Camera) f32 {
        return self.camera.zoom;
    }

    /// Zoom in
    pub fn zoomIn(self: *Camera) void {
        self.setZoom(self.target_zoom + self.zoom_speed);
    }

    /// Zoom out
    pub fn zoomOut(self: *Camera) void {
        self.setZoom(self.target_zoom - self.zoom_speed);
    }

    /// Set camera rotation in degrees
    pub fn setRotation(self: *Camera, degrees: f32) void {
        self.camera.rotation = degrees;
    }

    /// Get camera rotation in degrees
    pub fn getRotation(self: *Camera) f32 {
        return self.camera.rotation;
    }

    /// Rotate camera in degrees
    pub fn rotate(self: *Camera, degrees: f32) void {
        self.camera.rotation += degrees;
        // Keep rotation in 0-360 range
        while (self.camera.rotation >= 360.0) self.camera.rotation -= 360.0;
        while (self.camera.rotation < 0.0) self.camera.rotation += 360.0;
    }

    /// Convert world coordinates to screen coordinates
    pub fn worldToScreen(self: *Camera, world_pos: rl.Vector2) rl.Vector2 {
        return rl.getScreenToWorld2D(world_pos, self.camera);
    }

    /// Convert screen coordinates to world coordinates
    pub fn screenToWorld(self: *Camera, screen_pos: rl.Vector2) rl.Vector2 {
        return rl.getScreenToWorld2D(screen_pos, self.camera);
    }

    /// Focus camera on a target position (lerps based on pan_lerp_speed)
    pub fn focusOn(self: *Camera, x: f32, y: f32) void {
        self.target_position = rl.Vector2{ .x = x, .y = y };
    }

    /// Get the camera's raylib Camera2D struct for drawing
    pub fn getRayLibCamera(self: *Camera) rl.Camera2D {
        return self.camera;
    }

    /// Reset camera to default state at position
    pub fn reset(self: *Camera, x: f32, y: f32) void {
        const pos = rl.Vector2{ .x = x, .y = y };
        self.camera.target = pos;
        self.target_position = pos;
        self.camera.rotation = 0.0;
        self.camera.zoom = 1.0;
        self.target_zoom = 1.0;
    }

    /// Constrain camera to world bounds
    pub fn constrainToBounds(self: *Camera, world_width: f32, world_height: f32) void {
        const view_width = 800.0 / self.camera.zoom;
        const view_height = 600.0 / self.camera.zoom;

        // Clamp camera position to world bounds
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
