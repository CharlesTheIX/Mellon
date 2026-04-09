const std = @import("std");

pub const HTTP = struct {
    server: Server,

    pub fn init(port: u16) ?HTTP {
        const server = Server.init(port) catch |err| {
            std.debug.print("Failed to initialize HTTP server: {any}\n", .{err});
            return null;
        };
        return .{ .server = server };
    }

    pub fn deinit(self: *HTTP) void {
        self.server.deinit();
    }

    // . -------------------------------------------------------------------------
    pub fn start(self: HTTP) void {
        var listener = self.server.listen() catch |err| {
            std.debug.print("Failed to start HTTP server: {any}\n", .{err});
            return;
        };
        defer listener.deinit();

        while (true) {
            const connection = listener.accept() catch |err| {
                std.debug.print("Failed to accept connection: {any}\n", .{err});
                break;
            };
            defer connection.stream.close();

            const request = Request.read(connection) catch |err| {
                std.debug.print("Failed to read HTTP request: {any}\n", .{err});
                Response.internalError().send(connection);
                continue;
            };

            switch (request.method) {
                .Invalid => {
                    std.debug.print("Received invalid HTTP method\n", .{});
                    Response.bad().send(connection);
                    continue;
                },
                else => self.handleRequest(request).send(connection),
            }
        }
    }

    fn handleRequest(self: *const HTTP, request: Request) Response {
        std.debug.print(
            "Received GET request: {s} {s} {s}\n",
            .{ request.method.toString(), request.target, request.version },
        );

        for (request.headers[0..request.headers_len]) |header| {
            std.debug.print("{s}: {s}\n", .{ header.name, header.value });
        }

        if (request.params_len > 0) {
            std.debug.print("Query Parameters:\n", .{});
            for (request.params[0..request.params_len]) |param| {
                std.debug.print("  {s} = {s}\n", .{ param.name, param.value });
            }
        }
        _ = self;
        return Response.ok();
    }
};

const Header = struct { name: []const u8, value: []const u8 };

const Method = enum {
    GET,
    PUT,
    POST,
    HEAD,
    PATCH,
    DELETE,
    OPTIONS,
    Invalid,

    // . -------------------------------------------------------------------------
    pub fn get(method: []const u8) Method {
        if (std.mem.eql(u8, method, "GET")) return Method.GET;
        if (std.mem.eql(u8, method, "PUT")) return Method.PUT;
        if (std.mem.eql(u8, method, "POST")) return Method.POST;
        if (std.mem.eql(u8, method, "HEAD")) return Method.HEAD;
        if (std.mem.eql(u8, method, "PATCH")) return Method.PATCH;
        if (std.mem.eql(u8, method, "DELETE")) return Method.DELETE;
        if (std.mem.eql(u8, method, "OPTIONS")) return Method.OPTIONS;
        return .Invalid;
    }

    pub fn toString(self: Method) []const u8 {
        return switch (self) {
            .GET => "GET",
            .PUT => "PUT",
            .POST => "POST",
            .HEAD => "HEAD",
            .PATCH => "PATCH",
            .DELETE => "DELETE",
            .OPTIONS => "OPTIONS",
            .Invalid => "INVALID",
        };
    }
};

const Param = struct { name: []const u8, value: []const u8 };

const Response = struct {
    content: []const u8,
    type: ResponseType = .InternalError,

    pub fn init() Response {
        return .{ .content = "", .type = .InternalError };
    }

    pub fn deinit(self: *Response) void {
        _ = self;
    }

    // . -------------------------------------------------------------------------
    pub fn internalError() Response {
        const header = "HTTP/1.1 500 Internal Server Error\r\n" ++
            "Content-Length: {d}\r\n" ++
            "Connection: close\r\n" ++
            "Content-type: text/html\r\n\r\n";
        const content = "<!Doctype html><html><body><h1>SERVER ERROR</h1></body></html>";
        const header_formatted = std.fmt.allocPrint(std.heap.page_allocator, header, .{content.len}) catch |err| {
            std.debug.print("Failed to format response header: {any}\n", .{err});
            std.process.exit(1);
        };
        defer std.heap.page_allocator.free(header_formatted);
        const full_content = std.mem.concat(std.heap.page_allocator, u8, &.{ header_formatted, content }) catch |err| {
            std.debug.print("Failed to assemble response body: {any}\n", .{err});
            std.process.exit(1);
        };
        return .{ .type = .InternalError, .content = full_content };
    }

    pub fn ok() Response {
        const header = "HTTP/1.1 200 OK\r\n" ++
            "Content-Length: {d}\r\n" ++
            "Connection: close\r\n" ++
            "Content-type: text/html\r\n\r\n";
        const content = "<!Doctype html><html><body><h1>Hello, World!</h1></body></html>";
        const header_formatted = std.fmt.allocPrint(std.heap.page_allocator, header, .{content.len}) catch |err| {
            std.debug.print("Failed to format response header: {any}\n", .{err});
            return Response.internalError();
        };
        defer std.heap.page_allocator.free(header_formatted);
        const full_content = std.mem.concat(std.heap.page_allocator, u8, &.{ header_formatted, content }) catch |err| {
            std.debug.print("Failed to assemble response body: {any}\n", .{err});
            return Response.internalError();
        };
        return .{ .type = .Ok, .content = full_content };
    }

    pub fn bad() Response {
        const header = "HTTP/1.1 400 Bad Request\r\n" ++
            "Content-Length: {d}\r\n" ++
            "Connection: close\r\n" ++
            "Content-type: text/html\r\n\r\n";
        const content = "<!Doctype html><html><body><h1>Bad Request</h1></body></html>";
        const header_formatted = std.fmt.allocPrint(std.heap.page_allocator, header, .{content.len}) catch |err| {
            std.debug.print("Failed to format response header: {any}\n", .{err});
            return Response.internalError();
        };
        defer std.heap.page_allocator.free(header_formatted);
        const full_content = std.mem.concat(std.heap.page_allocator, u8, &.{ header_formatted, content }) catch |err| {
            std.debug.print("Failed to assemble response body: {any}\n", .{err});
            return Response.internalError();
        };
        return .{ .type = .NotFound, .content = full_content };
    }

    pub fn send(self: Response, connection: std.net.Server.Connection) void {
        return connection.stream.writeAll(self.content) catch |err| std.debug.print("Failed to send response: {any}\n", .{err});
    }
};

const ResponseType = enum {
    Ok,
    NotFound,
    InternalError,

    pub fn init() ResponseType {
        return .InternalError;
    }

    pub fn deinit(self: *ResponseType) void {
        _ = self;
    }

    // . -------------------------------------------------------------------------
    pub fn toString(self: ResponseType) []const u8 {
        return switch (self) {
            .Ok => "OK",
            .NotFound => "Not Found",
            .InternalError => "Internal Server Error",
        };
    }

    pub fn toStatusLine(self: ResponseType) []const u8 {
        return switch (self) {
            .Ok => "HTTP/1.1 200 OK\r\n",
            .NotFound => "HTTP/1.1 404 Not Found\r\n",
            .InternalError => "HTTP/1.1 500 Internal Server Error\r\n",
        };
    }
};

const Request = struct {
    method: Method,
    buffer: [8192]u8,
    path: []const u8,
    body: ?[]const u8,
    params_len: usize,
    params: [32]Param,
    headers_len: usize,
    target: []const u8,
    version: []const u8,
    headers: [32]Header,

    pub fn init() Request {
        return .{
            .path = "",
            .body = null,
            .target = "",
            .version = "",
            .params_len = 0,
            .headers_len = 0,
            .method = .Invalid,
            .buffer = undefined,
            .params = undefined,
            .headers = undefined,
        };
    }

    pub fn deinit(self: *Request) void {
        _ = self;
    }

    // . -------------------------------------------------------------------------
    pub fn read(connection: std.net.Server.Connection) !Request {
        var request = Request{
            .params_len = 0,
            .path = "",
            .headers_len = 0,
            .target = "",
            .body = null,
            .version = "",
            .method = .Invalid,
            .buffer = undefined,
            .params = undefined,
            .headers = undefined,
        };

        var total_read: usize = 0;
        while (true) {
            if (total_read == request.buffer.len) return error.RequestTooLarge;
            const bytes_read = try connection.stream.read(request.buffer[total_read..]);
            if (bytes_read == 0) {
                if (total_read == 0) return error.ConnectionClosed;
                break;
            }
            total_read += bytes_read;
            if (std.mem.indexOf(u8, request.buffer[0..total_read], "\r\n\r\n") != null) break;
        }

        const raw_request = request.buffer[0..total_read];
        const header_end = std.mem.indexOf(u8, raw_request, "\r\n\r\n") orelse return error.InvalidRequest;
        const header_block = raw_request[0..header_end];
        const body_start = header_end + 4;
        const request_line_end = std.mem.indexOf(u8, header_block, "\r\n") orelse header_block.len;
        const request_line = header_block[0..request_line_end];
        var request_parts = std.mem.splitScalar(u8, request_line, ' ');

        // Get method, target, and version
        const method = Method.get(request_parts.first());
        if (method == .Invalid) return error.InvalidMethod;
        request.method = method;
        request.target = request_parts.next() orelse return error.InvalidRequest;
        request.version = request_parts.next() orelse return error.InvalidRequest;

        // Parse query parameters for GET requests
        if (method == .GET) try request.parseTarget();

        // Parse headers
        if (request_line_end < header_block.len) {
            const header_lines = header_block[request_line_end + 2 ..];
            var lines = std.mem.splitSequence(u8, header_lines, "\r\n");
            while (lines.next()) |line| {
                if (line.len == 0) continue;
                if (request.headers_len == request.headers.len) return error.TooManyHeaders;
                const separator = std.mem.indexOfScalar(u8, line, ':') orelse return error.InvalidHeader;
                const name = std.mem.trim(u8, line[0..separator], " ");
                const value = std.mem.trim(u8, line[separator + 1 ..], " ");
                request.headers[request.headers_len] = .{ .name = name, .value = value };
                request.headers_len += 1;
            }
        }

        // Read body if Content-Length is specified
        const content_length = request.parseContentLength() catch return error.InvalidContentLength;
        const expected_end = body_start + content_length;
        if (expected_end > request.buffer.len) return error.RequestTooLarge;
        while (total_read < expected_end) {
            const bytes_read = try connection.stream.read(request.buffer[total_read..]);
            if (bytes_read == 0) return error.UnexpectedEof;
            total_read += bytes_read;
        }

        // For non-GET requests, we treat the body as raw data
        if (method != .GET) request.body = request.buffer[body_start .. body_start + content_length];
        return request;
    }

    fn parseTarget(self: *Request) !void {
        const query_index = std.mem.indexOfScalar(u8, self.target, '?');
        self.path = if (query_index) |idx| self.target[0..idx] else self.target;

        const query = if (query_index) |idx|
            self.target[idx + 1 ..]
        else
            return;

        if (query.len == 0) return;
        var parts = std.mem.splitScalar(u8, query, '&');
        while (parts.next()) |part| {
            if (part.len == 0) continue;
            if (self.params_len == self.params.len) return error.TooManyParams;
            const separator = std.mem.indexOfScalar(u8, part, '=');
            const name = std.mem.trim(u8, if (separator) |idx| part[0..idx] else part, " ");
            const value = std.mem.trim(u8, if (separator) |idx| part[idx + 1 ..] else "", " ");
            self.params[self.params_len] = .{ .name = name, .value = value };
            self.params_len += 1;
        }
    }

    fn parseContentLength(self: *const Request) !usize {
        if (self.getHeader("Content-Length")) |value| return try std.fmt.parseInt(usize, value, 10);
        return 0;
    }

    fn getHeader(self: *const Request, name: []const u8) ?[]const u8 {
        for (self.headers[0..self.headers_len]) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, name)) return header.value;
        }
        return null;
    }

    fn getParam(self: *const Request, name: []const u8) ?[]const u8 {
        for (self.params[0..self.params_len]) |param| {
            if (std.mem.eql(u8, param.name, name)) return param.value;
        }
        return null;
    }
};

const Server = struct {
    port: u16,
    host: []const u8,
    addr: std.net.Address,

    pub fn init(port: u16) !Server {
        const host: []const u8 = "127.0.0.1";
        const addr = try std.net.Address.parseIp4(host, port);
        return .{ .host = host, .port = port, .addr = addr };
    }

    pub fn deinit(self: *Server) void {
        _ = self;
    }

    // . -------------------------------------------------------------------------
    pub fn listen(self: Server) !std.net.Server {
        std.debug.print("Server listening on: {s}:{any}\n", .{ self.host, self.port });
        return try self.addr.listen(.{});
    }
};
