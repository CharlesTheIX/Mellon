const std = @import("std");
const Mellon = @import("mellon").Mellon;

pub fn main() !void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdin_reader = std.fs.File.stdin().readerStreaming(&stdin_buffer);
    var mellon = Mellon.init(&stdin_reader, &stdout_writer);
    defer mellon.deinit();
    try mellon.run();
}
