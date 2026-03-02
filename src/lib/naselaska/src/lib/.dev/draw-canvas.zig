const std = @import("std");
const rl = @import("raylib");
const Canvas = @import("../canvas.zig").Canvas;

pub fn canvas(canvas_obj: *Canvas, padding: [2]i32) [2]i32 {
    var y = padding[1];
    const alloc = std.heap.page_allocator;

    // Canvas width
    const canvas_width_str = std.fmt.allocPrint(
        alloc,
        "Width: {d}",
        .{@as(i32, @intFromFloat(canvas_obj.rect.width))},
    ) catch "Error";
    defer alloc.free(canvas_width_str);
    canvas_obj.drawText(canvas_width_str, padding[0], y, rl.Color.black);
    y += canvas_obj.lineSpacing(2);

    // Canvas height
    const canvas_height_str = std.fmt.allocPrint(
        alloc,
        "Height: {d}",
        .{@as(i32, @intFromFloat(canvas_obj.rect.height))},
    ) catch "Error";
    defer alloc.free(canvas_height_str);
    canvas_obj.drawText(canvas_height_str, padding[0], y, rl.Color.black);
    y += canvas_obj.lineSpacing(2);

    // Canvas position
    const canvas_pos_str = std.fmt.allocPrint(
        alloc,
        "Position: ({d}, {d})",
        .{ @as(i32, @intFromFloat(canvas_obj.rect.x)), @as(i32, @intFromFloat(canvas_obj.rect.y)) },
    ) catch "Error";
    defer alloc.free(canvas_pos_str);
    canvas_obj.drawText(canvas_pos_str, padding[0], y, rl.Color.black);
    y += canvas_obj.lineSpacing(2);

    // Font size
    const font_size_str = std.fmt.allocPrint(
        alloc,
        "Font Size: {d}",
        .{canvas_obj.font_size},
    ) catch "Error";
    defer alloc.free(font_size_str);
    canvas_obj.drawText(font_size_str, padding[0], y, rl.Color.black);
    y += canvas_obj.lineSpacing(2);

    // Font loaded
    const font_loaded_str = std.fmt.allocPrint(
        alloc,
        "Font Loaded: {s}",
        .{if (canvas_obj.font_loaded) "Yes" else "No"},
    ) catch "Error";
    defer alloc.free(font_loaded_str);
    canvas_obj.drawText(font_loaded_str, padding[0], y, rl.Color.black);
    y += canvas_obj.lineSpacing(2);

    // Custom font
    const custom_font_str = std.fmt.allocPrint(
        alloc,
        "Custom Font: {s}",
        .{if (canvas_obj.custom_font != null) "Yes" else "No"},
    ) catch "Error";
    defer alloc.free(custom_font_str);
    canvas_obj.drawText(custom_font_str, padding[0], y, rl.Color.black);
    y += canvas_obj.lineSpacing(2);

    // Line spacing test (show what current lineSpacing returns)
    const line_space_1x = canvas_obj.lineSpacing(1);
    const line_space_str = std.fmt.allocPrint(
        alloc,
        "Line Spacing (1x): {d}",
        .{line_space_1x},
    ) catch "Error";
    defer alloc.free(line_space_str);
    canvas_obj.drawText(line_space_str, padding[0], y, rl.Color.black);
    y += canvas_obj.lineSpacing(2);

    return .{ padding[0], y };
}
