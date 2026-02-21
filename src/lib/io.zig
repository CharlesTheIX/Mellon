const std = @import("std");
const History = @import("./history.zig").History;

const c = @cImport({
    @cInclude("unistd.h");
    @cInclude("termios.h");
});

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
    len: usize = 0,
    history: *History,
    cursor_pos: usize = 0,
    writer: *std.fs.File.Writer,
    reader: *std.fs.File.Reader,
    buffer: [1024]u8 = undefined,

    // Static Methods
    pub fn init(reader: *std.fs.File.Reader, writer: *std.fs.File.Writer, history: *History) IO {
        return IO{ .reader = reader, .writer = writer, .history = history };
    }

    // Instance Methods
    pub fn deinit(self: *IO) void {
        self.writer.interface.flush() catch {};
    }

    fn clear(self: *IO) void {
        self.len = 0;
        self.cursor_pos = 0;
    }

    fn insertChar(self: *IO, ch: u8) void {
        if (self.len >= self.buffer.len - 1) return;
        if (self.cursor_pos < self.len) {
            std.mem.copyBackwards(
                u8,
                self.buffer[self.cursor_pos + 1 .. self.len + 1],
                self.buffer[self.cursor_pos..self.len],
            );
        }
        self.buffer[self.cursor_pos] = ch;
        self.len += 1;
        self.cursor_pos += 1;
    }

    fn deleteChar(self: *IO) void {
        if (self.cursor_pos > 0 and self.len > 0) {
            if (self.cursor_pos < self.len) {
                std.mem.copyForwards(
                    u8,
                    self.buffer[self.cursor_pos - 1 .. self.len - 1],
                    self.buffer[self.cursor_pos..self.len],
                );
            }
            self.len -= 1;
            self.cursor_pos -= 1;
        }
    }

    fn setContent(self: *IO, content: []const u8) void {
        self.len = @min(content.len, self.buffer.len - 1);
        @memcpy(self.buffer[0..self.len], content[0..self.len]);
        self.cursor_pos = self.len;
    }

    fn getSlice(self: *IO) []const u8 {
        return self.buffer[0..self.len];
    }

    pub fn print(self: *IO, msg: []const u8, clr: Clr) !void {
        const code = clr.code();
        _ = try self.writer.interface.write(code);
        _ = try self.writer.interface.write(msg);
        _ = try self.writer.interface.write(Clr.Reset.code());
        try self.writer.interface.flush();
    }

    pub fn readLine(self: *IO) ![]const u8 {
        if (try self.reader.interface.takeDelimiter('\n')) |line| {
            // Trim carriage return if present (from Windows line endings)
            if (line.len > 0 and line[line.len - 1] == '\r') return line[0 .. line.len - 1];
            return line;
        }
        return "";
    }

    pub fn readLineWithHistory(self: *IO, buffer: []u8) ![]const u8 {
        const stdin = std.fs.File.stdin();
        var orig_termios: c.termios = undefined;
        _ = c.tcgetattr(stdin.handle, &orig_termios);

        var raw_termios = orig_termios;
        raw_termios.c_lflag &= ~(@as(c_uint, c.ECHO | c.ICANON));
        raw_termios.c_cc[c.VMIN] = 1;
        raw_termios.c_cc[c.VTIME] = 0;
        _ = c.tcsetattr(stdin.handle, c.TCSANOW, &raw_termios);

        defer {
            _ = c.tcsetattr(stdin.handle, c.TCSANOW, &orig_termios);
        }

        self.clear();

        while (true) {
            var ch: [1]u8 = undefined;
            const bytes_read = try stdin.read(&ch);
            if (bytes_read == 0) break;

            switch (ch[0]) {
                '\n', '\r' => {
                    try self.writer.interface.writeAll("\r\n");
                    const len = @min(self.len, buffer.len);
                    @memcpy(buffer[0..len], self.getSlice()[0..len]);
                    try self.history.add(buffer[0..len]);
                    try self.writer.interface.flush();
                    return buffer[0..len];
                },
                127, 8 => { // Backspace or DEL
                    self.deleteChar();
                    try self.redrawInput();
                },
                3 => { // Ctrl+C
                    try self.writer.interface.writeAll("^C\r\n");
                    self.clear();
                    return "";
                },
                27 => { // Escape sequence
                    var seq: [2]u8 = undefined;
                    const read1 = try stdin.read(seq[0..1]);
                    if (read1 == 0) continue;

                    if (seq[0] == '[') {
                        const read2 = try stdin.read(seq[1..2]);
                        if (read2 == 0) continue;

                        switch (seq[1]) {
                            'A' => { // Up arrow
                                if (self.history.navigateUp()) |cmd| {
                                    self.setContent(cmd);
                                    try self.redrawInput();
                                }
                            },
                            'B' => { // Down arrow
                                if (self.history.navigateDown()) |cmd| {
                                    self.setContent(cmd);
                                    try self.redrawInput();
                                }
                            },
                            'C' => { // Right arrow
                                if (self.cursor_pos < self.len) {
                                    self.cursor_pos += 1;
                                    try self.writer.interface.writeAll("\x1b[C");
                                }
                            },
                            'D' => { // Left arrow
                                if (self.cursor_pos > 0) {
                                    self.cursor_pos -= 1;
                                    try self.writer.interface.writeAll("\x1b[D");
                                }
                            },
                            else => {},
                        }
                    }
                },
                else => {
                    if (ch[0] >= 32 and ch[0] < 127) { // Printable characters
                        self.insertChar(ch[0]);
                        try self.redrawInput();
                    }
                },
            }
        }

        try self.writer.interface.flush();
        return "";
    }

    fn redrawInput(self: *IO) !void {
        try self.writer.interface.writeAll("\r\x1b[K");
        try self.writer.interface.writeAll(Clr.Green.code());
        try self.writer.interface.writeAll("⚡ ");
        try self.writer.interface.writeAll(Clr.Reset.code());
        try self.writer.interface.writeAll(self.getSlice());

        // Move cursor to correct position
        const chars_after_cursor = self.len - self.cursor_pos;
        if (chars_after_cursor > 0) {
            var buf: [16]u8 = undefined;
            const escape_seq = try std.fmt.bufPrint(&buf, "\x1b[{}D", .{chars_after_cursor});
            try self.writer.interface.writeAll(escape_seq);
        }
        try self.writer.interface.flush();
    }
};
