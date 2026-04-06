const std = @import("std");
const IO = @import("./io.zig").IO;
const ErrorHandler = @import("./error-handler.zig").ErrorHandler;

const WorkerCtx = struct {
    name: []const u8,
    duration_ns: u64,
    done: *std.atomic.Value(bool),
};

const SpinnerCtx = struct {
    io: *IO,
    hard_done: *std.atomic.Value(bool),
    medium_done: *std.atomic.Value(bool),
};

pub const _Dev = struct {
    io: *IO,
    Err: *ErrorHandler,

    pub fn init(Err: *ErrorHandler, io: *IO) _Dev {
        return _Dev{ .Err = Err, .io = io };
    }

    // Methods
    pub fn controller(self: *_Dev, args: []const u8) void {
        if (args.len == 0) return self.placeholder() catch |err| {
            return self.Err.handle(err, "Failed to display help\n\n", false, true);
        };
        var arg_parts = std.mem.splitSequence(u8, args, " ");
        const func = Fn.get(arg_parts.first());
        switch (func) {
            .PLACEHOLDER => return self.placeholder() catch |err| {
                return self.Err.handle(err, "Failed to run placeholder test\n\n", false, true);
            },
            else => return self.help() catch |err| {
                return self.Err.handle(err, "Failed to display help\n\n", false, true);
            },
        }
    }

    fn help(self: *_Dev) !void {
        self.io.print("Usage: _dev <function>\n\n", .Yellow);
        self.io.print("Available test functions:\n", .White);
        self.io.print("  placeholder - A placeholder test function\n", .White);
    }

    fn placeholder(self: *_Dev) !void {
        self.io.print("Running placeholder test...\n", .Yellow);
        var hard_done = std.atomic.Value(bool).init(false);
        var medium_done = std.atomic.Value(bool).init(false);
        const cpus = std.Thread.getCpuCount() catch |err| {
            return self.Err.handle(err, "Failed to get CPU count\n\n", true, true);
        };
        std.debug.print("Detected {any} CPU cores\n", .{cpus});
        const cpu_id = std.Thread.getCurrentId();
        std.debug.print("Current thread ID: {any}\n", .{cpu_id});
        const hard_ctx = WorkerCtx{
            .name = "hard",
            .done = &hard_done,
            .duration_ns = std.time.ns_per_s * 5,
        };
        const medium_ctx = WorkerCtx{
            .name = "medium",
            .done = &medium_done,
            .duration_ns = std.time.ns_per_s * 3,
        };
        const spinner_ctx = SpinnerCtx{
            .io = self.io,
            .hard_done = &hard_done,
            .medium_done = &medium_done,
        };
        var hard_thread = std.Thread.spawn(.{}, doWork, .{hard_ctx}) catch |err| {
            return self.Err.handle(err, "Failed to spawn hard worker thread\n\n", true, true);
        };
        var medium_thread = std.Thread.spawn(.{}, doWork, .{medium_ctx}) catch |err| {
            return self.Err.handle(err, "Failed to spawn medium worker thread\n\n", true, true);
        };
        var spinner_thread = std.Thread.spawn(.{}, renderSpinners, .{spinner_ctx}) catch |err| {
            return self.Err.handle(err, "Failed to spawn spinner thread\n\n", true, true);
        };
        hard_thread.detach();
        medium_thread.detach();
        spinner_thread.join();
        self.io.print("Placeholder test completed!\n\n", .Green);
    }

    fn doWork(ctx: WorkerCtx) void {
        std.Thread.sleep(ctx.duration_ns);
        ctx.done.store(true, .release);
    }

    fn renderSpinners(ctx: SpinnerCtx) void {
        var i: usize = 0;
        const frames = [_][]const u8{ "|", "/", "-", "\\" };
        ctx.io.print("hard [ ]\nmedium [ ]\n", .White);
        while (true) {
            const hard_is_done = ctx.hard_done.load(.acquire);
            const medium_is_done = ctx.medium_done.load(.acquire);
            const hard_token = if (hard_is_done) "done" else frames[i % frames.len];
            const medium_token = if (medium_is_done) "done" else frames[i % frames.len];
            var frame_buf: [96]u8 = undefined;
            const frame = std.fmt.bufPrint(
                &frame_buf,
                "\x1b[2A\r\x1b[2Khard [{s}]\n\r\x1b[2Kmedium [{s}]\n",
                .{ hard_token, medium_token },
            ) catch return;
            ctx.io.print(frame, .Red);
            if (hard_is_done and medium_is_done) break;
            i += 1;
            std.Thread.sleep(90 * std.time.ns_per_ms);
        }
    }
};

const Fn = enum {
    PLACEHOLDER,
    Invalid,

    fn get(string: []const u8) Fn {
        if (std.mem.eql(u8, string, "placeholder")) return .PLACEHOLDER;
        return .Invalid;
    }
};
