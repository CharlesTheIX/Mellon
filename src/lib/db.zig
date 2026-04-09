const std = @import("std");

pub const DbConfig = struct {
    port: u16 = 5432,
    user: []const u8 = "mellon",
    password: ?[]const u8 = null,
    host: []const u8 = "127.0.0.1",
    database: []const u8 = "mellon",
};

pub const DB = struct {
    allocator: std.mem.Allocator,
    stream: ?std.net.Stream = null,

    pub fn init(allocator: std.mem.Allocator) DB {
        return .{
            .allocator = allocator,
            .stream = null,
        };
    }

    pub fn deinit(self: *DB) void {
        self.disconnect();
    }

    // . -------------------------------------------------------------------------
    pub fn connect(self: *DB, cfg: DbConfig) !void {
        self.disconnect();

        var stream = try std.net.tcpConnectToHost(self.allocator, cfg.host, cfg.port);
        errdefer stream.close();

        try sendStartupMessage(stream, cfg);
        try completeAuthentication(stream, cfg);

        self.stream = stream;
    }

    pub fn disconnect(self: *DB) void {
        if (self.stream) |stream| {
            stream.close();
            self.stream = null;
        }
    }

    pub fn ping(self: *DB) !void {
        try self.simpleQuery("SELECT 1;");
    }

    pub fn simpleQuery(self: *DB, query: []const u8) !void {
        const stream = self.stream orelse return error.NotConnected;
        try sendQueryMessage(stream, query);
        try drainUntilReady(stream);
    }

    fn sendStartupMessage(stream: std.net.Stream, cfg: DbConfig) !void {
        var body = std.ArrayList(u8).init(std.heap.page_allocator);
        defer body.deinit();

        try appendInt32(&body, 196608); // protocol version 3.0
        try body.appendSlice("user");
        try body.append(0);
        try body.appendSlice(cfg.user);
        try body.append(0);
        try body.appendSlice("database");
        try body.append(0);
        try body.appendSlice(cfg.database);
        try body.append(0);
        try body.appendSlice("client_encoding");
        try body.append(0);
        try body.appendSlice("UTF8");
        try body.append(0);
        try body.append(0);

        var frame = std.ArrayList(u8).init(std.heap.page_allocator);
        defer frame.deinit();

        const message_len: usize = body.items.len + 4;
        if (message_len > std.math.maxInt(i32)) return error.MessageTooLarge;
        try appendInt32(&frame, @as(i32, @intCast(message_len)));
        try frame.appendSlice(body.items);
        try stream.writeAll(frame.items);
    }

    fn completeAuthentication(stream: std.net.Stream, cfg: DbConfig) !void {
        while (true) {
            const message = try readMessage(stream);
            defer std.heap.page_allocator.free(message.payload);

            switch (message.tag) {
                'R' => try handleAuthRequest(stream, cfg, message.payload),
                'S', 'K', 'N' => {},
                'E' => return error.AuthenticationFailed,
                'Z' => return,
                else => return error.UnexpectedServerMessage,
            }
        }
    }

    fn handleAuthRequest(stream: std.net.Stream, cfg: DbConfig, payload: []const u8) !void {
        if (payload.len < 4) return error.InvalidServerMessage;

        const auth_code = std.mem.readInt(i32, payload[0..4], .big);
        switch (auth_code) {
            0 => return,
            3 => {
                const password = cfg.password orelse return error.PasswordRequired;
                try sendPasswordMessage(stream, password);
            },
            5 => return error.UnsupportedAuthMethodMd5,
            10 => return error.UnsupportedAuthMethodSasl,
            else => return error.UnsupportedAuthMethod,
        }
    }

    fn sendPasswordMessage(stream: std.net.Stream, password: []const u8) !void {
        var frame = std.ArrayList(u8).init(std.heap.page_allocator);
        defer frame.deinit();

        try frame.append('p');

        const message_len: usize = password.len + 1 + 4;
        if (message_len > std.math.maxInt(i32)) return error.MessageTooLarge;
        try appendInt32(&frame, @as(i32, @intCast(message_len)));
        try frame.appendSlice(password);
        try frame.append(0);

        try stream.writeAll(frame.items);
    }

    fn sendQueryMessage(stream: std.net.Stream, query: []const u8) !void {
        var frame = std.ArrayList(u8).init(std.heap.page_allocator);
        defer frame.deinit();

        try frame.append('Q');

        const message_len: usize = query.len + 1 + 4;
        if (message_len > std.math.maxInt(i32)) return error.MessageTooLarge;
        try appendInt32(&frame, @as(i32, @intCast(message_len)));
        try frame.appendSlice(query);
        try frame.append(0);

        try stream.writeAll(frame.items);
    }

    fn drainUntilReady(stream: std.net.Stream) !void {
        while (true) {
            const message = try readMessage(stream);
            defer std.heap.page_allocator.free(message.payload);

            switch (message.tag) {
                'C', 'D', 'T', '1', '2', 'n', 'I', 'N' => {},
                'E' => return error.QueryFailed,
                'Z' => return,
                else => return error.UnexpectedServerMessage,
            }
        }
    }

    const Message = struct {
        tag: u8,
        payload: []u8,
    };

    fn readMessage(stream: std.net.Stream) !Message {
        var tag_buf: [1]u8 = undefined;
        try stream.readNoEof(&tag_buf);

        var len_buf: [4]u8 = undefined;
        try stream.readNoEof(&len_buf);

        const msg_len_i32 = std.mem.readInt(i32, &len_buf, .big);
        if (msg_len_i32 < 4) return error.InvalidServerMessage;

        const payload_len: usize = @as(usize, @intCast(msg_len_i32 - 4));
        const payload = try std.heap.page_allocator.alloc(u8, payload_len);
        errdefer std.heap.page_allocator.free(payload);
        if (payload_len > 0) try stream.readNoEof(payload);

        return .{
            .tag = tag_buf[0],
            .payload = payload,
        };
    }

    fn appendInt32(list: *std.ArrayList(u8), value: i32) !void {
        var buf: [4]u8 = undefined;
        std.mem.writeInt(i32, &buf, value, .big);
        try list.appendSlice(&buf);
    }
};
