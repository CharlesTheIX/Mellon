const std = @import("std");
const rl = @import("raylib");
const Canvas = @import("../canvas.zig").Canvas;
const Camera = @import("../camera.zig").Camera;
const Key = @import("../input-handler.zig").Key;
const Click = @import("../input-handler.zig").Click;
const IH = @import("../input-handler.zig").InputHandler;
const AH = @import("../audio-handler.zig").AudioHandler;
const AudioType = @import("../audio-handler.zig").AudioType;

pub fn clicks(canvas: *Canvas, ih: *IH, padding: [2]i32) [2]i32 {
    var pos: usize = 0;
    var y = padding[1];
    var buffer: [256]u8 = undefined;
    const alloc = std.heap.page_allocator;
    var click_iter = ih.*.active_clicks.iterator();
    while (click_iter.next()) |click| {
        const name = Click.toString(click.key_ptr.*);
        if (pos > 0 and pos < buffer.len) {
            buffer[pos] = ',';
            pos += 1;
        }
        const click_name_len = name.len;
        if (pos + click_name_len < buffer.len) {
            @memcpy(buffer[pos..][0..click_name_len], name);
            pos += click_name_len;
        }
    }
    if (pos < buffer.len) buffer[pos] = 0;
    const click_str: [:0]const u8 = buffer[0..pos :0];
    const active_clicks = std.fmt.allocPrint(alloc, "Active Clicks: {s}", .{click_str}) catch "Error";
    defer alloc.free(active_clicks);
    canvas.drawText(active_clicks, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);
    return .{ padding[0], y };
}

pub fn keys(canvas: *Canvas, ih: *IH, padding: [2]i32) [2]i32 {
    var pos: usize = 0;
    var y = padding[1];
    var buffer: [256]u8 = undefined;
    const alloc = std.heap.page_allocator;
    var key_iter = ih.*.active_keys.iterator();
    while (key_iter.next()) |key| {
        const name = Key.toString(key.key_ptr.*);
        if (pos > 0 and pos < buffer.len) {
            buffer[pos] = ',';
            pos += 1;
        }
        const key_name_len = name.len;
        if (pos + key_name_len < buffer.len) {
            @memcpy(buffer[pos..][0..key_name_len], name);
            pos += key_name_len;
        }
    }
    if (pos < buffer.len) buffer[pos] = 0;
    const key_str: [:0]const u8 = buffer[0..pos :0];
    const active_keys = std.fmt.allocPrint(alloc, "Active Keys: {s}", .{key_str}) catch "Error";
    defer alloc.free(active_keys);
    canvas.drawText(active_keys, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);
    return .{ padding[0], y };
}

pub fn mouse(canvas: *Canvas, ih: *IH, camera: *Camera, padding: [2]i32) [2]i32 {
    var y = padding[1];
    const alloc = std.heap.page_allocator;
    const mouse_screen_pos = ih.mouseScreenPos();
    const mouse_world_pos = ih.mouseWorldPos(camera);
    const mouse_screen_pos_str = std.fmt.allocPrint(
        alloc,
        "Mouse Screen Position: ({d}, {d})",
        .{ mouse_screen_pos.x, mouse_screen_pos.y },
    ) catch "Error";
    defer alloc.free(mouse_screen_pos_str);
    const mouse_world_pos_str = std.fmt.allocPrint(
        alloc,
        "Mouse World Position: ({d}, {d})",
        .{ mouse_world_pos.x, mouse_world_pos.y },
    ) catch "Error";
    defer alloc.free(mouse_world_pos_str);
    canvas.drawText(mouse_screen_pos_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);
    canvas.drawText(mouse_world_pos_str, padding[0], y, rl.Color.black);
    y += canvas.lineSpacing(2);
    return .{ padding[0], y };
}

pub fn audio(canvas: *Canvas, audio_type: AudioType, ah: *AH, padding: [2]i32) [2]i32 {
    var y = padding[1];
    const alloc = std.heap.page_allocator;
    switch (audio_type) {
        .Music => {
            const audio_count_str = std.fmt.allocPrint(alloc, "Loaded Count: {d}", .{ah.music.count()}) catch "Error";
            canvas.drawText(audio_count_str, padding[0], y, rl.Color.black);
            defer alloc.free(audio_count_str);
            y += canvas.lineSpacing(2);
            var iter = ah.music.iterator();
            while (iter.next()) |entry| {
                const audio_str = std.fmt.allocPrint(alloc, "-> {s}", .{entry.key_ptr.*}) catch "Error";
                defer alloc.free(audio_str);
                canvas.drawText(audio_str, padding[0], y, rl.Color.black);
                y += canvas.lineSpacing(2);
            }
        },
        .Sound => {
            const audio_count_str = std.fmt.allocPrint(alloc, "Loaded Count: {d}", .{ah.sounds.count()}) catch "Error";
            canvas.drawText(audio_count_str, padding[0], y, rl.Color.black);
            defer alloc.free(audio_count_str);
            y += canvas.lineSpacing(2);
            var iter = ah.sounds.iterator();
            while (iter.next()) |entry| {
                const audio_str = std.fmt.allocPrint(alloc, "-> {s}", .{entry.key_ptr.*}) catch "Error";
                defer alloc.free(audio_str);
                canvas.drawText(audio_str, padding[0], y, rl.Color.black);
                y += canvas.lineSpacing(2);
            }
        },
    }
    return .{ padding[0], y };
}
