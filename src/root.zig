const std = @import("std");
const FS = @import("./lib/file-system.zig").FileSystem;

const Command = enum {
    Exit,
    FileSystem,
    Help,
    Invalid,
};

pub const Mellon = struct {
    file_system: FS,
    reader: *std.fs.File.Reader,
    writer: *std.fs.File.Writer,

    pub fn controller(self: *Mellon, cmd: []const u8, args: []const u8) !void {
        const commandType = stringToCommand(cmd);
        switch (commandType) {
            .Exit => try self.exit(0),
            .FileSystem => try self.file_system.controller(args),
            .Help => try self.help(),
            .Invalid => {
                try self.writer.interface.print("Unknown command: {s}\n", .{cmd});
                try self.writer.interface.flush();
            },
        }
    }

    pub fn deinit(self: *Mellon) void {
        self.file_system.deinit();
    }

    fn exit(self: *Mellon, status: u8) !void {
        try self.writer.interface.print("Exiting with status: {}\n", .{status});
        try self.writer.interface.flush();
        std.process.exit(status);
    }

    fn help(self: *Mellon) !void {
        try self.writer.interface.print("Hello\n", .{});
        try self.writer.interface.flush();
    }

    pub fn init(reader: *std.fs.File.Reader, writer: *std.fs.File.Writer) Mellon {
        return Mellon{ .reader = reader, .writer = writer, .file_system = FS.init(writer) };
    }
};

fn stringToCommand(string: []const u8) Command {
    if (std.mem.eql(u8, string, "exit") or std.mem.eql(u8, string, ":q")) return .Exit;
    if (std.mem.eql(u8, string, "file_system") or std.mem.eql(u8, string, "fs")) return .FileSystem;
    if (std.mem.eql(u8, string, "help")) return .Help;
    return .Invalid;
}
