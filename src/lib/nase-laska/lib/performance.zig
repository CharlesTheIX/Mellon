const std = @import("std");

pub const Performance = struct {
    max_samples: usize,
    frame_times: std.ArrayList(u64),

    pub fn init(allocator: std.mem.Allocator, max_samples: usize) Performance {
        return .{
            .max_samples = max_samples,
            .frame_times = std.ArrayList(u64).init(allocator),
        };
    }

    pub fn deinit(self: *Performance) void {
        self.frame_times.deinit();
    }

    pub fn recordFrameTime(self: *Performance, time_ns: u64) void {
        if (self.frame_times.items.len == self.max_samples) {
            // Remove the oldest sample to make room for the new one
            _ = self.frame_times.orderedRemove(0);
        }
        self.frame_times.append(time_ns) catch {};
    }

    /// Calculate average frame time in milliseconds
    pub fn averageFrameTime(self: *Performance) f64 {
        if (self.frame_times.items.len == 0) return 0.0;
        var sum: u64 = 0;
        for (self.frame_times.items) |time| sum += time;
        const avg_ns = sum / self.frame_times.items.len;
        return @as(f64, @floatFromInt(avg_ns)) / 1_000_000.0; // Convert to ms
    }

    /// Calculate frames per second (FPS) based on average frame time
    pub fn fps(self: *Performance) f64 {
        const avg_ms = self.averageFrameTime();
        if (avg_ms <= 0) return 0.0;
        return 1000.0 / avg_ms;
    }

    /// Get the maximum frame time in milliseconds
    pub fn maxFrameTime(self: *Performance) f64 {
        if (self.frame_times.items.len == 0) return 0.0;
        var max: u64 = 0;
        for (self.frame_times.items) |time| {
            if (time > max) max = time;
        }
        return @as(f64, @floatFromInt(max)) / 1_000_000.0;
    }

    /// Get the minimum frame time in milliseconds
    pub fn minFrameTime(self: *Performance) f64 {
        if (self.frame_times.items.len == 0) return 0.0;
        var min: u64 = std.math.maxInt(u64);
        for (self.frame_times.items) |time| {
            if (time < min) min = time;
        }
        return if (min == std.math.maxInt(u64)) 0.0 else @as(f64, @floatFromInt(min)) / 1_000_000.0;
    }

    /// Estimate CPU usage based on frame time vs target frame time (assumes 60 FPS target)
    pub fn cpuUsage(self: *Performance) f64 {
        const target_frame_time_ms = 1000.0 / 60.0; // 60 FPS target
        const avg_ms = self.averageFrameTime();
        const usage = (avg_ms / target_frame_time_ms) * 100.0;
        // Clamp to 0-100%
        return if (usage > 100.0) 100.0 else if (usage < 0.0) 0.0 else usage;
    }

    /// Get current memory usage by this process in bytes (approximate)
    pub fn ramUsage(self: *Performance) usize {
        // Try to get memory information from the system
        if (std.os.getuid != null and std.os.getuid() == 0) {
            // Running with elevated privileges, could query system
            // For now, return approximate allocation
        }
        // Return approximate memory used by frame_times buffer
        return self.frame_times.items.len * @sizeOf(u64);
    }

    /// Get memory allocated for frame timing buffer in bytes
    pub fn allocatedMemory(self: *Performance) usize {
        return self.frame_times.capacity * @sizeOf(u64);
    }

    /// Get number of samples recorded
    pub fn sampleCount(self: *Performance) usize {
        return self.frame_times.items.len;
    }
};
