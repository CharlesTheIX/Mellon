const std = @import("std");
const IO = @import("mellon").IO;
const Mellon = @import("mellon").Mellon;
const Config = @import("mellon").Config;
const ErrorHandler = @import("mellon").ErrorHandler;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var Err = ErrorHandler.init(allocator);
    var config = Config.init(allocator, &Err);
    defer config.deinit();
    Err.log_dir = config.log_dir;
    var stdin_buffer: [1024]u8 = undefined;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    var stdin_reader = std.fs.File.stdin().readerStreaming(&stdin_buffer);
    var io = IO.init(allocator, &stdin_reader, &stdout_writer, &config, &Err);
    defer io.deinit();
    var mellon = Mellon.init(allocator, &io, &config, &Err);

    const args = std.process.argsAlloc(allocator) catch |err| {
        return Err.handle(err, "Failed to allocate memory for command line arguments\n\n", true, true);
    };
    defer std.process.argsFree(allocator, args);
    const cli_args = if (args.len > 1) args[1..] else &[_][]const u8{}; // Skip the program name (args[0])
    mellon.run(cli_args);
    std.process.exit(0);
}
