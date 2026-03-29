const std = @import("std");
pub const IO = @import("./lib/core/io.zig").IO;
const Search = @import("./lib/search.zig").Search;
const Shell = @import("./lib/core/shell.zig").Shell;
const clear = @import("./lib/core/utils.zig").clear;
pub const Config = @import("./lib/core/config.zig").Config;
const FS = @import("./lib/core/file-system.zig").FileSystem;
pub const ErrorHandler = @import("./lib/core/error-handler.zig").ErrorHandler;
const readFile = @import("./lib/core/utils.zig").readFile;

pub const Mellon = struct {
    fs: FS,
    io: *IO,
    shell: Shell,
    search: Search,
    config: *Config,
    Err: *ErrorHandler,

    pub fn init(io: *IO, config: *Config, Err: *ErrorHandler) Mellon {
        const search = Search.init(Err);
        const shell = Shell.init(io, Err);
        const fs = FS.init(io, config, Err);
        return Mellon{
            .io = io,
            .fs = fs,
            .shell = shell,
            .search = search,
            .config = config,
            .Err = Err,
        };
    }

    // Instance Methods
    pub fn run(self: *Mellon, args: []const []const u8) void {
        if (args.len == 0) return self.repl() catch |err| {
            return self.Err.handle(err, "An error occurred while running REPL\n\n", true, true);
        };
        const cmd = args[0];
        if (std.mem.eql(u8, cmd, "repl")) return self.repl() catch |err| {
            return self.Err.handle(err, "An error occurred while running REPL\n\n", true, true);
        };
        const joined_args = std.mem.join(std.heap.page_allocator, " ", args) catch "";
        const cmd_args = if (args.len > 1) joined_args else "";
        defer if (cmd_args.len > 0) std.heap.page_allocator.free(cmd_args);
        self.controller(cmd, cmd_args) catch |err| {
            return self.Err.handle(err, "An error occurred while running command\n\n", true, true);
        };
    }

    // Private Methods
    fn benchmark(self: *Mellon, args: []const u8) !void {
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
        self.io.print(msg, .Cyan);
    }

    fn controller(self: *Mellon, cmd: []const u8, args: []const u8) anyerror!void {
        const command = Cmd.get(cmd);
        switch (command) {
            .Benchmark => return try benchmark(self, args),
            .Config => return self.config.controller(args),
            .Exit => return try self.exit(200),
            .FileSystem => return self.fs.controller(args),
            .Help => return try self.help(),
            .Repl => return,
            .Search => return self.search.controller(args),
            .Invalid => return self.shell.controller(cmd, args),
        }
    }

    fn exit(self: *Mellon, status: u8) !void {
        switch (status) {
            0 => self.io.print("✅ Exiting Successfully\n\n", .Green),
            1 => self.io.print("⚠️ Exiting with Warnings\n\n", .Yellow),
            200 => {
                self.io.print("Goodbye! 👋\n\n", .Green);
                std.process.exit(0);
            },
            else => {
                const msg = try std.fmt.allocPrint(std.heap.page_allocator, "❌ Exiting with Errors (code: {d})\n\n", .{status});
                defer std.heap.page_allocator.free(msg);
                self.io.print(msg, .Red);
            },
        }
        std.process.exit(status);
    }

    fn help(self: *Mellon) !void {
        clear();
        const content = try readFile("./docs/help.txt");
        self.io.print(content, .Green);
        self.io.print("\n\n", .White);
    }

    fn printIntro(self: *Mellon) !void {
        clear();
        const content = try readFile("./docs/intro.txt");
        self.io.print(content, .Green);
        self.io.print("\n\n", .White);
    }

    fn repl(self: *Mellon) !void {
        if (self.config.show_intro) try self.printIntro();
        while (true) {
            const prompt = self.config.getFullPrompt();
            defer self.config.allocator.free(prompt);
            self.io.print(prompt, .Green);
            var buffer: [1024]u8 = undefined;
            const line = self.io.readLineWithHistory(&buffer);
            if (line.len == 0) continue;
            self.io.history.add(line);
            var commands = std.mem.splitSequence(u8, line, " ");
            const command = commands.first();
            const args = commands.rest();
            try self.controller(command, args);
        }
    }
};

const Cmd = enum {
    Benchmark,
    Config,
    Exit,
    FileSystem,
    Help,
    Repl,
    Search,
    Invalid,

    fn get(string: []const u8) Cmd {
        if (std.mem.eql(u8, string, "benchmark") or std.mem.eql(u8, string, "bench")) return .Benchmark;
        if (std.mem.eql(u8, string, "config")) return .Config;
        if (std.mem.eql(u8, string, "exit") or std.mem.eql(u8, string, ":q")) return .Exit;
        if (std.mem.eql(u8, string, "file-system") or std.mem.eql(u8, string, "fs")) return .FileSystem;
        if (std.mem.eql(u8, string, "help")) return .Help;
        if (std.mem.eql(u8, string, "repl")) return .Repl;
        if (std.mem.eql(u8, string, "search") or std.mem.eql(u8, string, "s")) return .Search;
        return .Invalid;
    }
};
