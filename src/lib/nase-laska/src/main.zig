const std = @import("std");
const NaseLaska = @import("naselaska").NaseLaska;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    var nase_laska = NaseLaska.init(allocator);
    defer nase_laska.deinit();
    nase_laska.mainLoop() catch std.debug.print("❌ NaseLaska failed\n\n", .{});
    return std.process.exit(0);
}
