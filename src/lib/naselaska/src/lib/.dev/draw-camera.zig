const std = @import("std");
const rl = @import("raylib");
const Canvas = @import("../canvas.zig").Canvas;
const Camera = @import("../camera.zig").Camera;

pub fn camera(canvas: *Canvas, cam: *Camera, padding: [2]i32) [2]i32 {
    var y = padding[1];
    const alloc = std.heap.page_allocator;

    // Current position
    const current_pos = cam.getPosition();
    const current_pos_str = std.fmt.allocPrint(
        alloc,
        "Position: ({d:.2}, {d:.2})",
        .{ current_pos.x, current_pos.y },
    ) catch "Error";
    defer alloc.free(current_pos_str);
    canvas.drawText(current_pos_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // Target position
    const target_pos = cam.getTargetPosition();
    const target_pos_str = std.fmt.allocPrint(
        alloc,
        "Target: ({d:.2}, {d:.2})",
        .{ target_pos.x, target_pos.y },
    ) catch "Error";
    defer alloc.free(target_pos_str);
    canvas.drawText(target_pos_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // Current zoom
    const current_zoom = cam.getZoom();
    const current_zoom_str = std.fmt.allocPrint(
        alloc,
        "Zoom: {d:.2}",
        .{current_zoom},
    ) catch "Error";
    defer alloc.free(current_zoom_str);
    canvas.drawText(current_zoom_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // Target zoom
    const target_zoom = cam.target_zoom;
    const target_zoom_str = std.fmt.allocPrint(
        alloc,
        "Target Zoom: {d:.2}",
        .{target_zoom},
    ) catch "Error";
    defer alloc.free(target_zoom_str);
    canvas.drawText(target_zoom_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // Rotation
    const rotation = cam.getRotation();
    const rotation_str = std.fmt.allocPrint(
        alloc,
        "Rotation: {d:.2}°",
        .{rotation},
    ) catch "Error";
    defer alloc.free(rotation_str);
    canvas.drawText(rotation_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // Pan speed
    const pan_speed_str = std.fmt.allocPrint(
        alloc,
        "Pan Speed: {d:.2}",
        .{cam.pan_speed},
    ) catch "Error";
    defer alloc.free(pan_speed_str);
    canvas.drawText(pan_speed_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // Zoom speed
    const zoom_speed_str = std.fmt.allocPrint(
        alloc,
        "Zoom Speed: {d:.2}",
        .{cam.zoom_speed},
    ) catch "Error";
    defer alloc.free(zoom_speed_str);
    canvas.drawText(zoom_speed_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // Zoom bounds
    const zoom_bounds_str = std.fmt.allocPrint(
        alloc,
        "Zoom Bounds: [{d:.2}, {d:.2}]",
        .{ cam.min_zoom, cam.max_zoom },
    ) catch "Error";
    defer alloc.free(zoom_bounds_str);
    canvas.drawText(zoom_bounds_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // Pan lerp speed
    const lerp_speed_str = std.fmt.allocPrint(
        alloc,
        "Pan Lerp Speed: {d:.2}",
        .{cam.pan_lerp_speed},
    ) catch "Error";
    defer alloc.free(lerp_speed_str);
    canvas.drawText(lerp_speed_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    return .{ padding[0], y };
}
