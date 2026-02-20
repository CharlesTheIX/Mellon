const std = @import("std");

pub const Clr = enum {
    Blue,
    Cyan,
    Green,
    Magenta,
    Red,
    White,
    Yellow,
    Reset,

    fn code(self: Clr) []const u8 {
        return switch (self) {
            .Blue => "\x1b[34m",
            .Cyan => "\x1b[36m",
            .Green => "\x1b[32m",
            .Magenta => "\x1b[35m",
            .Red => "\x1b[31m",
            .White => "\x1b[37m",
            .Yellow => "\x1b[33m",
            .Reset => "\x1b[0m",
        };
    }
};

pub const IO = struct {
    writer: *std.fs.File.Writer,
    reader: *std.fs.File.Reader,

    // Static Methods
    pub fn init(reader: *std.fs.File.Reader, writer: *std.fs.File.Writer) IO {
        return IO{ .reader = reader, .writer = writer };
    }

    // Instance Methods
    pub fn deinit(self: *IO) !void {
        _ = try self.writer.interface.flush();
    }

    pub fn print(self: *IO, msg: []const u8, clr: Clr) !void {
        const code = clr.code();
        _ = try self.writer.interface.write(code);
        _ = try self.writer.interface.write(msg);
        _ = try self.writer.interface.write("\x1b[0m");
        try self.writer.interface.flush();
    }
};
