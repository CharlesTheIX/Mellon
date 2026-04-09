const std = @import("std");
const rl = @import("raylib");
const Window = @import("./window.zig").Window;
const Key = @import("./input_handler.zig").Key;
const InputHandler = @import("./input_handler.zig").InputHandler;

pub const Camera = struct {
    camera: rl.Camera2D,
    min_zoom: f32 = 1.0,
    max_zoom: f32 = 10.0,
    zoom_speed: f32 = 0.1,
    target_zoom: f32 = 3.0,
    pan_lerp_speed: f32 = 0.1,
    target_position: rl.Vector2,
    mouse_pan_start: rl.Vector2,
    mouse_pan_target: rl.Vector2,
    mouse_pan_active: bool = false,

    pub fn init(window: *Window) Camera {
        return .{
            .target_position = window.asVector2().scale(0.5),
            .mouse_pan_start = window.asVector2().scale(0.5),
            .mouse_pan_target = window.asVector2().scale(0.5),
            .camera = rl.Camera2D{
                .zoom = 3.0,
                .rotation = 0,
                .target = window.asVector2().scale(0.5),
                .offset = window.asVector2().scale(0.5),
            },
        };
    }

    pub fn deinit(self: *Camera) void {
        _ = self;
        // No resources to free
    }

    // . -------------------------------------------------------------------------
    pub fn resize(self: *Camera, new_offset: rl.Vector2) void {
        self.camera.offset = new_offset;
    }

    pub fn update(self: *Camera, input_handler: *InputHandler) void {
        self.handleZoom(input_handler);
        self.handleMovement(input_handler);
    }

    // MOVEMENT -------------------------------------------------------------------------
    fn handleMovement(self: *Camera, input_handler: *InputHandler) void {
        self.mouseMovement(input_handler);
        if (!self.mouse_pan_active) self.keyMovement(input_handler);
    }

    fn keyMovement(self: *Camera, input_handler: *InputHandler) void {
        var movement = rl.Vector2.zero();
        if (input_handler.keysActive(&[_]Key{.W}, .And)) movement.y -= 1;
        if (input_handler.keysActive(&[_]Key{.S}, .And)) movement.y += 1;
        if (input_handler.keysActive(&[_]Key{.A}, .And)) movement.x -= 1;
        if (input_handler.keysActive(&[_]Key{.D}, .And)) movement.x += 1;
        if (movement.x == 0 and movement.y == 0) return;
        self.camera.target = self.camera.target.add(movement);
        self.target_position = self.camera.target;
    }

    fn mouseMovement(self: *Camera, input_handler: *InputHandler) void {
        const mouse_pos = input_handler.mouseWindowPosition();
        if (input_handler.active_clicks.get(.Left) != null) {
            if (!self.mouse_pan_active) {
                self.mouse_pan_active = true;
                self.mouse_pan_start = mouse_pos;
                self.mouse_pan_target = self.camera.target;
            } else {
                const delta = mouse_pos.subtract(self.mouse_pan_start);
                self.target_position = self.mouse_pan_target.subtract(delta.scale(1.0 / self.camera.zoom));
            }
        } else {
            self.mouse_pan_active = false;
        }

        // Smoothly interpolate camera target towards target_position
        const diff = self.target_position.subtract(self.camera.target);
        self.camera.target = self.camera.target.add(diff.scale(self.pan_lerp_speed));
    }

    // ZOOM -------------------------------------------------------------------------
    fn handleZoom(self: *Camera, input_handler: *InputHandler) void {
        const has_modifier = input_handler.keysActive(&[_]Key{ .LeftShift, .RightShift }, .Or);
        if (has_modifier) {
            const zoom_in = input_handler.keysActive(&[_]Key{.Equal}, .Or);
            const zoom_out = input_handler.keysActive(&[_]Key{.Minus}, .Or);
            if (zoom_in) self.setZoom(self.target_zoom + self.zoom_speed);
            if (zoom_out) self.setZoom(self.target_zoom - self.zoom_speed);
        }

        if (self.camera.zoom != self.target_zoom) {
            const diff = self.target_zoom - self.camera.zoom;
            const step = std.math.sign(diff) * self.zoom_speed;
            if (@abs(diff) < @abs(step)) self.camera.zoom = self.target_zoom else self.camera.zoom += step;
        }
    }

    fn setZoom(self: *Camera, zoom: f32) void {
        self.target_zoom = std.math.clamp(zoom, self.min_zoom, self.max_zoom);
    }
};
