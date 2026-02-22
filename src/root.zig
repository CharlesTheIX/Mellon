const std = @import("std");
pub const IO = @import("./lib/core/io.zig").IO;
const Shell = @import("./lib/core/shell.zig").Shell;
pub const Config = @import("./lib/core/config.zig").Config;
const FS = @import("./lib/core/file-system.zig").FileSystem;

pub const NaseLaska = @import("./lib/nase-laska/root.zig").NaseLaska;

pub const Mellon = struct {
    fs: FS,
    io: *IO,
    shell: Shell,
    config: *Config,

    // Static Methods
    pub fn init(io: *IO, config: *Config) Mellon {
        // pub fn init(allocator: std.mem.Allocator) Mellon {
        // var stdin_buffer: [1024]u8 = undefined;
        // var stdout_buffer: [1024]u8 = undefined;
        // var config = Config.init(allocator);
        // var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        // var stdin_reader = std.fs.File.stdin().readerStreaming(&stdin_buffer);
        // var io = IO.init(allocator, &stdin_reader, &stdout_writer, &config);

        const shell = Shell.init(io);
        const fs = FS.init(io, config);
        return Mellon{ .io = io, .shell = shell, .fs = fs, .config = config };
    }

    // Instance Methods
    pub fn benchmark(self: *Mellon, args: []const u8) anyerror!void {
        if (args.len == 0) return self.io.print("Usage: benchmark <command> [args]\n\n", .Yellow);
        var parts = std.mem.splitSequence(u8, args, " ");
        const cmd = parts.first();
        const cmd_args = parts.rest();
        if (cmd.len == 0) return self.io.print("Usage: benchmark <command> [args]\n\n", .Yellow);
        const start = std.time.nanoTimestamp();

        try self.controller(cmd, cmd_args);

        const end = std.time.nanoTimestamp();
        const elapsed_ns: u64 = if (end >= start) @as(u64, @intCast(end - start)) else 0;
        const elapsed_ms = @as(u64, elapsed_ns / std.time.ns_per_ms);
        const msg = try std.fmt.allocPrint(
            std.heap.page_allocator,
            "\n⏱️  Benchmark: {s} {s}\nElapsed: {d} ms ({d} ns)\n\n",
            .{ cmd, cmd_args, elapsed_ms, elapsed_ns },
        );
        defer std.heap.page_allocator.free(msg);
        try self.io.print(msg, .Cyan);
    }

    fn controller(self: *Mellon, cmd: []const u8, args: []const u8) !void {
        const command = Cmd.get(cmd);
        switch (command) {
            .Benchmark => return try benchmark(self, args),
            .Config => return try self.config.controller(args),
            .Exit => return try self.exit(200),
            .FileSystem => return try self.fs.controller(args),
            .Help => return try self.help(),
            .Repl => return,
            .Invalid => return try self.shell.controller(cmd, args),
        }
    }

    pub fn deinit(self: *Mellon) void {
        self.fs.deinit();
        // self.io.deinit();
        self.shell.deinit();
        // self.config.deinit();
    }

    fn exit(self: *Mellon, status: u8) !void {
        switch (status) {
            0 => try self.io.print("✅ Exiting Successfully\n\n", .Green),
            1 => try self.io.print("⚠️ Exiting with Warnings\n\n", .Yellow),
            200 => {
                try self.io.print("Goodbye! 👋\n\n", .Green);
                std.process.exit(0);
            },
            else => {
                const msg = try std.fmt.allocPrint(std.heap.page_allocator, "❌ Exiting with Errors (code: {d})\n\n", .{status});
                defer std.heap.page_allocator.free(msg);
                try self.io.print(msg, .Red);
            },
        }
        std.process.exit(status);
    }

    fn help(self: *Mellon) !void {
        try Shell.clear();
        const content = try self.fs.readFile("./docs/help.txt");
        try self.io.print(content, .Green);
        try self.io.print("\n\n", .White);
    }

    fn printIntro(self: *Mellon) !void {
        try Shell.clear();
        const content = try self.fs.readFile("./docs/intro.txt");
        try self.io.print(content, .Green);
        try self.io.print("\n\n", .White);
    }

    fn repl(self: *Mellon) !void {
        if (self.config.show_intro) try self.printIntro();

        while (true) {
            const prompt = try self.config.getFullPrompt();
            defer self.config.allocator.free(prompt);
            try self.io.print(prompt, .Green);
            var buffer: [1024]u8 = undefined;
            const line = try self.io.readLineWithHistory(&buffer);
            if (line.len == 0) continue;
            try self.io.history.add(line);

            var commands = std.mem.splitSequence(u8, line, " ");
            const command = commands.first();
            const args = commands.rest();
            try self.controller(command, args);
        }
    }

    pub fn run(self: *Mellon, args: []const []const u8) !void {
        if (args.len == 0) return try self.repl();
        const cmd = args[0];
        if (std.mem.eql(u8, cmd, "repl")) return try self.repl();
        const cmd_args = if (args.len > 1) try std.mem.join(std.heap.page_allocator, " ", args[1..]) else "";
        defer if (cmd_args.len > 0) std.heap.page_allocator.free(cmd_args);
        try self.controller(cmd, cmd_args);
    }
};

const Cmd = enum {
    Benchmark,
    Config,
    Exit,
    FileSystem,
    Help,
    Repl,
    Invalid,

    fn get(string: []const u8) Cmd {
        if (std.mem.eql(u8, string, "benchmark") or std.mem.eql(u8, string, "bench")) return .Benchmark;
        if (std.mem.eql(u8, string, "config")) return .Config;
        if (std.mem.eql(u8, string, "exit") or std.mem.eql(u8, string, ":q")) return .Exit;
        if (std.mem.eql(u8, string, "file-system") or std.mem.eql(u8, string, "fs")) return .FileSystem;
        if (std.mem.eql(u8, string, "help")) return .Help;
        if (std.mem.eql(u8, string, "repl")) return .Repl;
        return .Invalid;
    }
};
