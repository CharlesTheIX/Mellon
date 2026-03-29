const std = @import("std");
const ErrorHandler = @import("./core/error-handler.zig").ErrorHandler;

pub const Search = struct {
    Err: *ErrorHandler,

    pub fn init(Err: *ErrorHandler) Search {
        return Search{ .Err = Err };
    }

    pub fn controller(self: *Search, query: []const u8) void {
        if (query.len == 0) return;
        const allocator = std.heap.page_allocator;
        const args_array = &[3][]const u8{ "rg", "--vimgrep", query };
        var child_process = std.process.Child.init(args_array, allocator);
        _ = child_process.spawnAndWait() catch |err| {
            return self.Err.handle(err, "Failed to execute search command\n\n", false, true);
        };
    }
};
