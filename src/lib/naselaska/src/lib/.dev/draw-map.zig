const std = @import("std");
const rl = @import("raylib");
const Map = @import("../map.zig").Map;
const Canvas = @import("../canvas.zig").Canvas;

pub fn map(canvas: *Canvas, map_obj: *Map, padding: [2]i32) [2]i32 {
    var y = padding[1];
    const alloc = std.heap.page_allocator;

    // Map ID
    const map_id_str = std.fmt.allocPrint(
        alloc,
        "ID: {s}",
        .{map_obj.id},
    ) catch "Error";
    defer alloc.free(map_id_str);
    canvas.drawText(map_id_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // Map name
    const map_name_str = std.fmt.allocPrint(
        alloc,
        "Name: {s}",
        .{map_obj.name},
    ) catch "Error";
    defer alloc.free(map_name_str);
    canvas.drawText(map_name_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // Map dimensions
    const map_dims_str = std.fmt.allocPrint(
        alloc,
        "Dimensions: {d} x {d}",
        .{ @as(i32, @intFromFloat(map_obj.rect.width)), @as(i32, @intFromFloat(map_obj.rect.height)) },
    ) catch "Error";
    defer alloc.free(map_dims_str);
    canvas.drawText(map_dims_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // Data directory
    const data_dir_str = std.fmt.allocPrint(
        alloc,
        "Data Dir: {s}",
        .{map_obj.data_dir},
    ) catch "Error";
    defer alloc.free(data_dir_str);
    canvas.drawText(data_dir_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // Background image status
    const bg_img_status_str = std.fmt.allocPrint(
        alloc,
        "Background Loaded: {s}",
        .{if (map_obj.bg_img != null) "Yes" else "No"},
    ) catch "Error";
    defer alloc.free(bg_img_status_str);
    canvas.drawText(bg_img_status_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // Spawn points count
    const spawn_count_str = std.fmt.allocPrint(
        alloc,
        "Spawn Points: {d}",
        .{map_obj.spawn_points.len},
    ) catch "Error";
    defer alloc.free(spawn_count_str);
    canvas.drawText(spawn_count_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);

    // List each spawn point
    for (map_obj.spawn_points, 0..) |point, i| {
        const x = @as(i32, @intCast(point & 0xFFFF));
        const y_coord = @as(i32, @intCast((point >> 16) & 0xFFFF));
        const spawn_str = std.fmt.allocPrint(
            alloc,
            "  [{d}] ({d}, {d})",
            .{ i, x, y_coord },
        ) catch "Error";
        defer alloc.free(spawn_str);
        canvas.drawText(spawn_str, padding[0], y, rl.Color.black);
        y += canvas.lineSpacing(2);
    }

    return .{ padding[0], y };
}
