const std = @import("std");
const mellon = @import("mellon").Mellon;

pub fn main() !void {
    var stdin_buffer: [1024]u8 = undefined;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdin_reader = std.fs.File.stdin().readerStreaming(&stdin_buffer);

    const stdin = &stdin_reader;
    const stdout = &stdout_writer;
    var cmd = mellon.init(stdin, stdout);
    defer cmd.deinit();

    while (true) {
        try stdout.interface.print("\x1b[33m⚡ ", .{});
        try stdout.interface.flush();

        const line_opt = try stdin.interface.takeDelimiter('\n');
        if (line_opt == null) break;

        const line = line_opt.?;
        if (line.len == 0) continue;

        var commands = std.mem.splitSequence(u8, line, " ");
        const command = commands.first();
        const args = commands.rest();
        try cmd.controller(command, args);
    }
}
