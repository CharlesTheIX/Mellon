const std = @import("std");
const IO = @import("mellon").IO;
const Mellon = @import("mellon").Mellon;
const Config = @import("mellon").Config;
const NaseLaska = @import("mellon").NaseLaska;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const cli_args = if (args.len > 1) args[1..] else &[_][]const u8{}; // Skip the program name (args[0])
    if (args.len > 1 and std.mem.eql(u8, args[1], "nase-laska")) {
        var nase_laska = NaseLaska.init(allocator);
        defer nase_laska.deinit();
        nase_laska.mainLoop() catch std.debug.print("❌ NaseLaska failed\n\n", .Red);
        return std.process.exit(0);
    }

    var config = Config.init(allocator);
    defer config.deinit();

    var stdin_buffer: [1024]u8 = undefined;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdin_reader = std.fs.File.stdin().readerStreaming(&stdin_buffer);
    var io = IO.init(allocator, &stdin_reader, &stdout_writer, &config);
    defer io.deinit();

    var mellon = Mellon.init(&io, &config);
    // var mellon = Mellon.init(allocator);
    defer mellon.deinit();
    return try mellon.run(cli_args);
}
