const std = @import("std");
const rl = @import("raylib");

pub const tile_size = 16;

fn tileIndexToPixel(source_rect: *rl.Rectangle, index: *u32) ?rl.Vector2 {
    const tiles_per_row = @as(u32, source_rect.width) / tile_size;
    const x = (@as(u32, index) % tiles_per_row) * tile_size;
    const y = (@as(u32, index) / tiles_per_row) * tile_size;
    if (x >= @as(u32, source_rect.width) or y >= @as(u32, source_rect.height)) return null;
    return rl.Vector2{ .x = @as(f32, x), .y = @as(f32, y) };
}

fn pixelToTileIndex(source_rect: *rl.Rectangle, pixel: rl.Vector2) ?u32 {
    if (pixel.x < 0 or pixel.y < 0 or pixel.x >= source_rect.width or pixel.y >= source_rect.height) return null;
    const tiles_per_row = @as(u32, source_rect.width) / tile_size;
    const x_index = @as(u32, pixel.x) / tile_size;
    const y_index = @as(u32, pixel.y) / tile_size;
    return y_index * tiles_per_row + x_index;
}

pub fn readFile(path: []const u8) []const u8 {
    const file_type = FileType.get(path);
    if (file_type == .Invalid) return "";

    const abs_path: []const u8 = getAbsPath(path) catch return "";
    var file = std.fs.openFileAbsolute(abs_path, .{ .mode = .read_only }) catch return "";
    defer file.close();

    const file_size = file.getEndPos() catch return "";
    if (file_size == 0) return "";
    if (file_size > 10 * 1024 * 1024) return "";

    const allocator = std.heap.page_allocator;
    const buffer = allocator.alloc(u8, file_size) catch return "";
    const file_bytes = file.readAll(buffer) catch {
        allocator.free(buffer);
        return "";
    };

    if (file_bytes != file_size) {
        allocator.free(buffer);
        return "";
    }
    return buffer[0..file_size];
}

const FileType = enum {
    JSON,
    Z,
    Invalid,

    fn get(path: []const u8) FileType {
        if (path.len == 0) return .Invalid;
        var path_parts = std.mem.splitSequence(u8, path, "/");
        var file_name: []const u8 = undefined;
        while (path_parts.next()) |part| file_name = part;
        var file_name_parts = std.mem.splitSequence(u8, file_name, ".");
        var file_type: []const u8 = "";
        while (file_name_parts.next()) |part| file_type = part;
        if (std.mem.eql(u8, file_type, "json")) return .JSON;
        if (std.mem.eql(u8, file_type, "z")) return .Z;
        return .Invalid;
    }
};

fn getAbsPath(path: []const u8) ![]const u8 {
    const path_first_char = path[0..1];
    if (std.mem.eql(u8, path_first_char, "/")) return path;

    const allocator = std.heap.page_allocator;
    if (std.mem.eql(u8, path_first_char, "~")) {
        const env = try std.process.getEnvMap(allocator);
        const home_path = env.get("HOME") orelse "";
        return try std.fs.path.join(allocator, &[_][]const u8{ home_path, "/", path[1..] });
    }

    var count: u8 = 0;
    var cwd_path: []const u8 = "";
    var path_parts = std.mem.splitSequence(u8, path, "/");
    while (path_parts.next()) |part| {
        if (std.mem.eql(u8, part, ".")) {
            count += 2;
            cwd_path = try std.fs.path.join(allocator, &[_][]const u8{ cwd_path, "." });
        } else if (std.mem.eql(u8, part, "..")) {
            if (count == 0) cwd_path = try std.fs.path.join(allocator, &[_][]const u8{ cwd_path, ".." });
            if (count >= 2) cwd_path = try std.fs.path.join(allocator, &[_][]const u8{ cwd_path, "/.." });
            count += 3;
        } else break;
    }

    const cwd = try std.fs.cwd().realpathAlloc(allocator, cwd_path);
    defer allocator.free(cwd);
    return try std.fs.path.join(allocator, &[_][]const u8{ cwd, "/", path[count..] });
}
