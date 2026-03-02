const std = @import("std");
const NaseLaska = @import("naselaska").NaseLaska;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    var naselaska = NaseLaska.init(allocator);
    defer naselaska.deinit();
    naselaska.run();
    return std.process.exit(0);
}
