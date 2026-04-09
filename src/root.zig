const std = @import("std");

// External Modules
const HTTP = @import("./lib/https.zig").HTTP;
const Gui = @import("./lib/gui/root.zig").Gui;
const Base64 = @import("./lib/base64.zig").Base64;

// Core Modules
pub const IO = @import("./lib/core/io.zig").IO;
const _Dev = @import("./lib/core/_dev.zig")._Dev;
const Shell = @import("./lib/core/shell.zig").Shell;
pub const Config = @import("./lib/core/config.zig").Config;
const FS = @import("./lib/core/file-system.zig").FileSystem;
pub const ErrorHandler = @import("./lib/core/error-handler.zig").ErrorHandler;

// Core Utils
const Editor = @import("./lib/core/utils.zig").Editor;
const clear = @import("./lib/core/utils.zig").clear;
const readFile = @import("./lib/core/utils.zig").readFile;
const openEditor = @import("./lib/core/utils.zig").openEditor;

pub const Mellon = struct {
    fs: FS,
    io: *IO,
    _dev: _Dev,
    shell: Shell,
    base64: Base64,
    config: *Config,
    Err: *ErrorHandler,
    http: ?HTTP = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, io: *IO, config: *Config, Err: *ErrorHandler) Mellon {
        const port: u16 = 3490;
        return Mellon{
            .io = io,
            .config = config,
            .Err = Err,
            .http = HTTP.init(port),
            .allocator = allocator,
            ._dev = _Dev.init(Err, io),
            .shell = Shell.init(io, Err),
            .fs = FS.init(io, config, Err),
            .base64 = Base64.init(allocator, io, Err, config),
        };
    }

    pub fn deinit(self: *Mellon) void {
        _ = self;
    }

    // . -------------------------------------------------------------------------
    pub fn run(self: *Mellon, args: []const []const u8) void {
        if (args.len == 0) return self.repl();
        const cmd = args[0];
        if (std.mem.eql(u8, cmd, "repl")) return self.repl();
        const joined_args = std.mem.join(std.heap.page_allocator, " ", args) catch "";
        const cmd_args = if (args.len > 1) joined_args else "";
        defer if (cmd_args.len > 0) std.heap.page_allocator.free(cmd_args);
        self.controller(cmd, cmd_args);
    }

    // -------------------------------------------------------------------------
    fn benchmark(self: *Mellon, args: []const u8) !void {
        if (args.len == 0) return self.io.print("Usage: benchmark <command> [args]\n\n", .Yellow);
        var parts = std.mem.splitSequence(u8, args, " ");
        const cmd = parts.first();
        const cmd_args = parts.rest();
        if (cmd.len == 0) return self.io.print("Usage: benchmark <command> [args]\n\n", .Yellow);
        const start = std.time.nanoTimestamp();
        self.controller(cmd, cmd_args);
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

    fn controller(self: *Mellon, cmd: []const u8, args: []const u8) void {
        const command = Cmd.get(cmd);
        switch (command) {
            .Repl => return,
            .Help => return self.help(),
            ._Dev => return self._dev.controller(args),
            .Config => return self.config.controller(args),
            .FileSystem => return self.fs.controller(args),
            .Base64 => return self.base64.controller(args),
            .Gui => {
                var gpa = std.heap.GeneralPurposeAllocator(.{}){};
                defer _ = gpa.deinit();
                const allocator = gpa.allocator();
                var gui = Gui.init(allocator);
                gui.run();
                defer gui.deinit();
                return self.exit(0) catch return std.process.exit(0);
            },
            .Exit => return self.exit(200) catch |err| {
                return self.Err.handle(err, "An error occurred while exiting\n\n", true, true);
            },
            .Benchmark => return benchmark(self, args) catch |err| {
                return self.Err.handle(err, "An error occurred while running benchmark\n\n", true, true);
            },
            .HTTP => {
                if (self.http) |http| return http.start();
                return self.Err.handle(error.Unavailable, "HTTP server is unavailable\n\n", false, true);
            },
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

    fn help(self: *Mellon) void {
        openEditor(Editor.get(self.config.editor), "./docs/help.md");
    }

    fn printIntro(self: *Mellon) void {
        clear();
        const content = readFile("./docs/intro.md") catch |err| {
            return self.Err.handle(err, "Failed to read intro content\n\n", false, true);
        };
        self.io.print("\n\n", .White);
        self.io.print(content, .White);
        self.io.print("\n\n", .White);
    }

    fn repl(self: *Mellon) void {
        if (self.config.show_intro) self.printIntro();
        while (true) {
            const prompt = if (self.config.prompt.get(self.allocator, self.Err)) |full_prompt|
                full_prompt
            else
                "ERROR_SETTING_PROMPT > ";
            defer self.config.allocator.free(prompt);
            self.io.print(prompt, .White);
            var buffer: [1024]u8 = undefined;
            const line = self.io.readLineWithHistory(&buffer);
            if (line.len == 0) continue;
            self.config.history.add(line);
            var commands = std.mem.splitSequence(u8, line, " ");
            const command = commands.first();
            const args = commands.rest();
            self.controller(command, args);
        }
    }
};

const Cmd = enum {
    Gui,
    _Dev,
    Exit,
    Repl,
    Help,
    HTTP,
    Config,
    Base64,
    Benchmark,
    FileSystem,
    Invalid,

    fn get(string: []const u8) Cmd {
        if (std.mem.eql(u8, string, "gui")) return .Gui;
        if (std.mem.eql(u8, string, "http")) return .HTTP;
        if (std.mem.eql(u8, string, "_dev")) return ._Dev;
        if (std.mem.eql(u8, string, "help")) return .Help;
        if (std.mem.eql(u8, string, "repl")) return .Repl;
        if (std.mem.eql(u8, string, "config")) return .Config;
        if (std.mem.eql(u8, string, "base64")) return .Base64;
        if (std.mem.eql(u8, string, "exit") or std.mem.eql(u8, string, ":q")) return .Exit;
        if (std.mem.eql(u8, string, "benchmark") or std.mem.eql(u8, string, "bench")) return .Benchmark;
        if (std.mem.eql(u8, string, "file-system") or std.mem.eql(u8, string, "fs")) return .FileSystem;
        return .Invalid;
    }
};
