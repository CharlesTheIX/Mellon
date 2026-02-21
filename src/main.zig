const std = @import("std");
const IO = @import("mellon").IO;
const Mellon = @import("mellon").Mellon;
const Config = @import("mellon").Config;
const History = @import("mellon").History;
const pwd = @import(".pwd.zig").pwd;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var config = Config.init(allocator);
    defer config.deinit();

    var history = History.init(allocator);
    defer history.deinit();

    var stdin_buffer: [1024]u8 = undefined;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdin_reader = std.fs.File.stdin().readerStreaming(&stdin_buffer);
    var io = IO.init(&stdin_reader, &stdout_writer, &history);
    defer io.deinit();

    var mellon = Mellon.init(&io, &config);
    defer mellon.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const cli_args = if (args.len > 1) args[1..] else &[_][]const u8{}; // Skip the program name (args[0])

    const password = try io.readPassword("Password: ");
    if (std.mem.eql(u8, password, pwd)) {
        try io.print("Password correct. Starting Mellon...", .Green);
        return try mellon.run(cli_args);
    }

    return try io.print("Incorrect password. Exiting.", .Red);
}
