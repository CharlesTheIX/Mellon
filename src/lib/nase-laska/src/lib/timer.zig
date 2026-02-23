const std = @import("std");

const State = enum { Ready, Paused, Running, Finished };

pub const Timer = struct {
    timeout: i128,
    start_time: i128 = 0,
    state: State = .Ready,

    pub fn init(timeout: i128) Timer {
        return .{ .timeout = timeout };
    }

    pub fn setState(self: *Timer, new_state: State) void {
        self.state = new_state;
    }

    pub fn update(self: *Timer) void {
        if (self.state != .Running) return;
        const now = std.time.nanoTimestamp();
        const elapsed = now - self.start_time;
        if (elapsed >= self.timeout) self.state = .Finished;
    }

    pub fn start(self: *Timer) void {
        self.start_time = std.time.nanoTimestamp();
        self.state = .Running;
    }

    pub fn reset(self: *Timer) void {
        self.start_time = 0;
        self.state = .Ready;
    }
};
