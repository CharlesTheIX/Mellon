const std = @import("std");
const rl = @import("raylib");
const Window = @import("./window.zig").Window;
const Key = @import("./input_handler/root.zig").Key;
const Keys = @import("./input_handler/root.zig").Keys;
const InputHandler = @import("./input_handler/root.zig").InputHandler;

pub const Zoom = struct {
    min: f32 = 1.0,
    max: f32 = 10.0,
    speed: f32 = 0.1,
    target: f32 = 3.0,

    pub fn init() Zoom {
        return Zoom{};
    }

    pub fn set(self: *Zoom, zoom: f32) void {
        self.target = std.math.clamp(zoom, self.min, self.max);
    }

    pub fn handleKeyInput(self: *Zoom, keys: *Keys, camera: *rl.Camera2D, lerp_speed: *f32) void {
        const has_modifier = keys.contains(&[_]Key{ .LeftShift, .RightShift }, .Or);
        if (has_modifier) {
            const zoom_in = keys.contains(&[_]Key{.Equal}, .Or);
            const zoom_out = keys.contains(&[_]Key{.Minus}, .Or);
            if (zoom_in) self.set(self.target + self.speed);
            if (zoom_out) self.set(self.target - self.speed);
        }

        const delta = self.target - camera.zoom;
        if (@abs(delta) > 0.001) {
            camera.zoom += delta * lerp_speed.*;
        } else {
            camera.zoom = self.target;
        }
    }

    fn scrollZoom(self: *Camera, scroll: *rl.Vector2) void {
        self.setZoom(self.target_zoom + self.invertScroll(scroll).y * self.zoom_speed);
        self.camera.zoom = self.target_zoom;
    }
};

pub const Camera = struct {
    zoom: Zoom,
    camera: rl.Camera2D,
    lerp_speed: f32 = 0.1,
    movement_speed: f32 = 32.0,
    target_position: rl.Vector2,
    min_zoom: f32 = 1.0,
    max_zoom: f32 = 10.0,
    zoom_speed: f32 = 0.1,
    target_zoom: f32 = 3.0,
    rotation_speed: f32 = 5.0,
    target_rotation: f32 = 0.0,
    mouse_pan_start: rl.Vector2,
    mouse_pan_target: rl.Vector2,
    mouse_pan_active: bool = false,

    pub fn init(window: *Window) Camera {
        const zoom = Zoom.init();
        return .{
            // .zoom = zoom,
            .target_rotation = 0.0,
            .target_position = window.asVector2().scale(0.5),
            .mouse_pan_start = window.asVector2().scale(0.5),
            .mouse_pan_target = window.asVector2().scale(0.5),
            .camera = rl.Camera2D{
                .rotation = 0,
                .zoom = zoom.target,
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
        // self.zoom.handleKeyInput(&input_handler.keys, &self.camera, &self.lerp_speed);
        self.handleZoom(input_handler);
        self.handleScroll(input_handler);
        self.handleMovement(input_handler);
        self.handleRotation(input_handler);
    }

    // MOVEMENT -------------------------------------------------------------------------
    fn handleMovement(self: *Camera, input_handler: *InputHandler) void {
        self.mouseMovement(input_handler);
        if (!self.mouse_pan_active) self.keyMovement(input_handler);
    }

    fn keyMovement(self: *Camera, input_handler: *InputHandler) void {
        var movement = rl.Vector2.zero();
        var speed = self.movement_speed;
        const has_modifier = input_handler.keys.contains(&[_]Key{ .LeftShift, .RightShift }, .Or);
        if (has_modifier) speed *= 4;
        if (input_handler.keys.contains(&[_]Key{.W}, .And)) movement.y -= 1;
        if (input_handler.keys.contains(&[_]Key{.S}, .And)) movement.y += 1;
        if (input_handler.keys.contains(&[_]Key{.A}, .And)) movement.x -= 1;
        if (input_handler.keys.contains(&[_]Key{.D}, .And)) movement.x += 1;
        if (movement.x == 0 and movement.y == 0) return;
        movement = self.rotateVector(movement, -self.camera.rotation);
        movement = movement.scale(speed * self.lerp_speed / self.camera.zoom);
        self.target_position = self.target_position.add(movement);
    }

    fn mouseMovement(self: *Camera, input_handler: *InputHandler) void {
        if (input_handler.mouse.active_clicks.get(.Left) != null) {
            const mouse_pos = input_handler.mouse.v2_window();
            const has_modifier = input_handler.keys.contains(&[_]Key{ .LeftShift, .RightShift }, .Or);
            if (has_modifier) return; // Don't pan if modifier is held (to allow for clicking + selecting UI elements)
            if (!self.mouse_pan_active) {
                self.mouse_pan_active = true;
                self.mouse_pan_start = mouse_pos;
                self.mouse_pan_target = self.camera.target;
            } else {
                var delta = mouse_pos.subtract(self.mouse_pan_start);
                delta = self.rotateVector(delta, -self.camera.rotation);
                self.target_position = self.mouse_pan_target.subtract(delta.scale(1.0 / self.camera.zoom));
            }
        } else {
            self.mouse_pan_active = false;
        }

        // Smoothly interpolate camera target towards target_position
        const diff = self.target_position.subtract(self.camera.target);
        self.camera.target = self.camera.target.add(diff.scale(self.lerp_speed));
    }

    fn scrollMovement(self: *Camera, scroll: *rl.Vector2) void {
        var movement = scroll.scale(self.movement_speed * self.lerp_speed / self.camera.zoom);
        movement = self.rotateVector(movement, -self.camera.rotation);
        movement = self.invertScroll(scroll);
        self.target_position = self.target_position.add(movement);
    }

    // SCROLL -------------------------------------------------------------------------
    fn handleScroll(self: *Camera, input_handler: *InputHandler) void {
        var scroll = input_handler.mouse.scroll();
        if (scroll.x == 0 and scroll.y == 0) return;
        const has_zoom_modifier = input_handler.keys.contains(&[_]Key{ .LeftShift, .RightShift }, .Or);
        if (has_zoom_modifier) return self.scrollZoom(&scroll);
        const has_rotation_modifier = input_handler.keys.contains(&[_]Key{ .LeftAlt, .RightAlt }, .Or);
        if (has_rotation_modifier) return self.scrollRotation(&scroll);
        return self.scrollMovement(&scroll);
    }

    fn invertScroll(self: *Camera, scroll: *rl.Vector2) rl.Vector2 {
        _ = self;
        return rl.Vector2{ .x = scroll.x * -1, .y = scroll.y * -1 };
    }

    // ROTATION -------------------------------------------------------------------------
    fn handleRotation(self: *Camera, input_handler: *InputHandler) void {
        const has_modifier = input_handler.keys.contains(&[_]Key{ .LeftShift, .RightShift }, .Or);
        if (has_modifier) {
            const rotate_left = input_handler.keys.contains(&[_]Key{.RightBracket}, .Or);
            const rotate_right = input_handler.keys.contains(&[_]Key{.LeftBracket}, .Or);
            if (rotate_left) self.target_rotation -= self.rotation_speed;
            if (rotate_right) self.target_rotation += self.rotation_speed;
        }

        const rotation_diff = self.target_rotation - self.camera.rotation;
        if (@abs(rotation_diff) > 0.001) {
            self.camera.rotation += rotation_diff * self.lerp_speed;
        } else {
            self.camera.rotation = self.target_rotation;
        }
    }

    fn rotateVector(self: *Camera, vec: rl.Vector2, angle_degrees: f32) rl.Vector2 {
        _ = self;
        const angle_radians = angle_degrees * std.math.pi / 180.0;
        const cos_a = @cos(angle_radians);
        const sin_a = @sin(angle_radians);
        return .{
            .x = vec.x * cos_a - vec.y * sin_a,
            .y = vec.x * sin_a + vec.y * cos_a,
        };
    }

    fn scrollRotation(self: *Camera, scroll: *rl.Vector2) void {
        self.target_rotation += self.invertScroll(scroll).y * self.rotation_speed;
    }

    // ZOOM -------------------------------------------------------------------------
    fn handleZoom(self: *Camera, input_handler: *InputHandler) void {
        const has_modifier = input_handler.keys.contains(&[_]Key{ .LeftShift, .RightShift }, .Or);
        if (has_modifier) {
            const zoom_in = input_handler.keys.contains(&[_]Key{.Equal}, .Or);
            const zoom_out = input_handler.keys.contains(&[_]Key{.Minus}, .Or);
            if (zoom_in) self.setZoom(self.target_zoom + self.zoom_speed);
            if (zoom_out) self.setZoom(self.target_zoom - self.zoom_speed);
        }

        const zoom_diff = self.target_zoom - self.camera.zoom;
        if (@abs(zoom_diff) > 0.001) {
            self.camera.zoom += zoom_diff * self.lerp_speed;
        } else {
            self.camera.zoom = self.target_zoom;
        }
    }

    fn scrollZoom(self: *Camera, scroll: *rl.Vector2) void {
        self.setZoom(self.target_zoom + self.invertScroll(scroll).y * self.zoom_speed);
        std.debug.print("taget Zoom: {d}\n", .{self.target_zoom});
        self.camera.zoom = self.target_zoom;
        std.debug.print("camera Zoom: {d}\n", .{self.camera.zoom});
    }

    fn setZoom(self: *Camera, zoom: f32) void {
        self.target_zoom = std.math.clamp(zoom, self.min_zoom, self.max_zoom);
    }
};
