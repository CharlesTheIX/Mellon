const std = @import("std");
const rl = @import("raylib");
const Map = @import("./map.zig").Map;
const IO = @import("../core/io.zig").IO;
const Config = @import("../core/config.zig").Config;
const FS = @import("../core/file-system.zig").FileSystem;

pub const NaseLaska = struct {
    fs: FS,
    io: IO,
    map: Map,
    config: Config,

    // Static Methods
    pub fn init(allocator: std.mem.Allocator) NaseLaska {
        var config = Config.init(allocator);
        defer config.deinit();

        var stdin_buffer: [1024]u8 = undefined;
        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        var stdin_reader = std.fs.File.stdin().readerStreaming(&stdin_buffer);
        var io = IO.init(allocator, &stdin_reader, &stdout_writer, &config);
        defer io.deinit();

        var fs = FS.init(&io, &config);
        const map = Map.init(&fs);
        return NaseLaska{ .io = io, .map = map, .config = config, .fs = fs };
    }

    // Instance Methods
    pub fn mainLoop(self: *NaseLaska) !void {
        self.map.load("test") catch return;

        rl.setTargetFPS(60);
        rl.initWindow(800, 600, "Naše Láska");
        defer rl.closeWindow();

        const alloc = std.heap.page_allocator;
        const text = std.fmt.allocPrint(alloc, "Name: {s}", .{self.map.name}) catch "Error";
        defer alloc.free(text);
        
        const text_z = try alloc.allocSentinel(u8, text.len, 0);
        @memcpy(text_z, text);

        while (!rl.windowShouldClose()) {
            rl.beginDrawing();
            rl.clearBackground(rl.Color.white);

            rl.drawText(text_z, 190, 200, 20, rl.Color.black);

            rl.endDrawing();
        }

        std.process.exit(0);
    }
};

const DataType = enum {
    Map,
    Invalid,

    pub fn get(string: []const u8) DataType {
        if (std.mem.eql(u8, string, "map")) return .Map;
        return .Invalid;
    }
};
