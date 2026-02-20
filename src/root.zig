const std = @import("std");
const IO = @import("./lib/io.zig").IO;
const Shell = @import("./lib/shell.zig").Shell;
const FS = @import("./lib/file-system.zig").FileSystem;

const Command = enum { Exit, FileSystem, Help, Invalid };

fn stringToCommand(string: []const u8) Command {
    if (std.mem.eql(u8, string, "exit") or std.mem.eql(u8, string, ":q")) return .Exit;
    if (std.mem.eql(u8, string, "file_system") or std.mem.eql(u8, string, "fs")) return .FileSystem;
    if (std.mem.eql(u8, string, "help")) return .Help;
    return .Invalid;
}

pub const Mellon = struct {
    io: IO,
    shell: Shell,
    file_system: FS,

    // Static Methods
    pub fn init(reader: *std.fs.File.Reader, writer: *std.fs.File.Writer) Mellon {
        const io = IO.init(reader, writer);
        const fs = FS.init(reader, writer);
        const shell = Shell.init(reader, writer);
        return Mellon{ .io = io, .shell = shell, .file_system = fs };
    }

    // Instance Methods
    fn controller(self: *Mellon, cmd: []const u8, args: []const u8) !void {
        const command = stringToCommand(cmd);
        switch (command) {
            .Exit => try self.exit(0),
            .FileSystem => try self.file_system.controller(args),
            .Help => try self.help(),
            .Invalid => try self.shell.controller(cmd, args),
        }
    }

    pub fn deinit(self: *Mellon) void {
        self.file_system.deinit() catch {};
        self.shell.deinit() catch {};
        self.io.deinit() catch {};
    }

    fn exit(self: *Mellon, status: u8) !void {
        const msg = try std.fmt.allocPrint(std.heap.page_allocator, "Exiting with status: {d}\n", .{status});
        defer std.heap.page_allocator.free(msg);
        try self.io.print(msg, .Blue);
        std.process.exit(status);
    }

    fn help(self: *Mellon) !void {
        try self.io.print("Help:\n", .Cyan);
    }

    pub fn run(self: *Mellon) !void {
        while (true) {
            const prompt = try std.fmt.allocPrint(std.heap.page_allocator, "⚡ ", .{});
            defer std.heap.page_allocator.free(prompt);
            try self.io.print(prompt, .Green);

            const line_opt = try self.io.reader.interface.takeDelimiter('\n');
            if (line_opt == null) break;
            const line = line_opt.?;
            if (line.len == 0) continue;

            var commands = std.mem.splitSequence(u8, line, " ");
            const command = commands.first();
            const args = commands.rest();
            try self.controller(command, args);
        }
    }
};
