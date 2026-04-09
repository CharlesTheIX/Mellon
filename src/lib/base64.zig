const std = @import("std");
const IO = @import("./core/io.zig").IO;
const Config = @import("./core/config.zig").Config;
const ErrorHandler = @import("./core/error-handler.zig").ErrorHandler;

pub const Base64 = struct {
    io: *IO,
    table: [64]u8,
    config: *Config,
    Err: *ErrorHandler,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, io: *IO, Err: *ErrorHandler, config: *Config) Base64 {
        const symbols = "+/";
        const digits = "0123456789";
        const uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        const lowercase = "abcdefghijklmnopqrstuvwxyz";
        return Base64{
            .io = io,
            .config = config,
            .Err = Err,
            .allocator = allocator,
            .table = (uppercase ++ lowercase ++ digits ++ symbols)[0..64].*,
        };
    }

    // . -------------------------------------------------------------------------
    pub fn controller(self: *Base64, args: []const u8) void {
        if (args.len == 0) return self.help();
        var arg_parts = std.mem.splitSequence(u8, args, " ");
        const func = Fn.get(arg_parts.first());
        var input: []const u8 = "";
        while (arg_parts.next()) |part| {
            if (std.mem.eql(u8, part, "")) break;
            if (std.mem.eql(u8, part[0..2], "--")) {
                var key_value = std.mem.splitSequence(u8, part, "=");
                const key = key_value.first();
                const value = key_value.rest();
                if (std.mem.eql(u8, key, "--input")) input = value;
            } else continue;
        }
        while (input.len == 0) {
            const msg = std.fmt.allocPrint(std.heap.page_allocator, "📂 Input {s} ", .{self.config.prompt.symbol}) catch "";
            self.io.print(msg, .Yellow);
            var buffer: [1024]u8 = undefined;
            var stdin_reader = std.fs.File.stdin().readerStreaming(&buffer);
            const line = stdin_reader.interface.takeDelimiter('\n') catch |err| {
                self.Err.handle(err, "Failed to read base64 input\n\n", false, true);
                return;
            } orelse "";
            input = line;
        }
        switch (func) {
            .Encode => {
                const encoded = self.encode(input) catch |err| {
                    return self.Err.handle(err, "Failed to encode input to base64\n\n", false, true);
                };
                self.io.print(encoded, .White);
                self.allocator.free(encoded);
                return;
            },
            .Decode => {
                const decoded = self.decode(input) catch |err| {
                    return self.Err.handle(err, "Failed to decode base64 input\n\n", false, true);
                };
                self.io.print(decoded, .White);
                self.allocator.free(decoded);
                return;
            },
            .Help => return self.help(),
            .Invalid => return self.io.print("❌ Invalid func: Please use 'help' OR '-h' for help.\n\n", .Red),
        }
    }

    // -------------------------------------------------------------------------
    fn calc_decode_length(input: []const u8) !usize {
        if (input.len < 4) return 3;
        const n_groups: usize = try std.math.divFloor(usize, input.len, 4);
        var multiple_groups: usize = n_groups * 3;
        var i: usize = input.len - 1;
        while (i > 0) : (i -= 1) {
            if (input[i] == '=') {
                multiple_groups -= 1;
            } else break;
        }
        return multiple_groups;
    }

    fn calc_encode_length(input: []const u8) !usize {
        if (input.len < 3) return 4;
        const n_groups: usize = try std.math.divCeil(usize, input.len, 3);
        return n_groups * 4;
    }

    pub fn char_at(self: *const Base64, index: u8) u8 {
        return self.table[index];
    }

    fn char_index(self: Base64, char: u8) u8 {
        if (char == '=') return 64;
        var i: u8 = 0;
        var output_index: u8 = 0;
        while (i < 64) : (i += 1) {
            if (self.char_at(i) == char) break;
            output_index += 1;
        }
        return output_index;
    }

    fn decode(self: Base64, input: []const u8) ![]u8 {
        if (input.len == 0) return "";
        var count: u8 = 0;
        var iout: u64 = 0;
        var buf = [4]u8{ 0, 0, 0, 0 };
        const n_output = try calc_decode_length(input);
        var output = try self.allocator.alloc(u8, n_output);
        for (0..input.len) |i| {
            buf[count] = self.char_index(input[i]);
            count += 1;
            if (count == 4) {
                output[iout] = (buf[0] << 2) + (buf[1] >> 4);
                if (buf[2] != 64) output[iout + 1] = (buf[1] << 4) + (buf[2] >> 2);
                if (buf[3] != 64) output[iout + 2] = (buf[2] << 6) + buf[3];
                iout += 3;
                count = 0;
            }
        }
        return output;
    }

    fn encode(self: Base64, input: []const u8) ![]u8 {
        if (input.len == 0) return "";
        var count: u8 = 0;
        var iout: u64 = 0;
        var buf = [3]u8{ 0, 0, 0 };
        const n_out = try calc_encode_length(input);
        var out = try self.allocator.alloc(u8, n_out);
        for (input, 0..) |_, i| {
            buf[count] = input[i];
            count += 1;
            if (count == 3) {
                out[iout] = self.char_at(buf[0] >> 2);
                out[iout + 1] = self.char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
                out[iout + 2] = self.char_at(((buf[1] & 0x0f) << 2) + (buf[2] >> 6));
                out[iout + 3] = self.char_at(buf[2] & 0x3f);
                iout += 4;
                count = 0;
            }
        }
        if (count == 1) {
            out[iout] = self.char_at(buf[0] >> 2);
            out[iout + 1] = self.char_at((buf[0] & 0x03) << 4);
            out[iout + 2] = '=';
            out[iout + 3] = '=';
        }
        if (count == 2) {
            out[iout] = self.char_at(buf[0] >> 2);
            out[iout + 1] = self.char_at(((buf[0] & 0x03) << 4) + (buf[1] >> 4));
            out[iout + 2] = self.char_at((buf[1] & 0x0f) << 2);
            out[iout + 3] = '=';
            iout += 4;
        }
        return out;
    }

    fn help(self: *Base64) void {
        const help_message = "Usage: search <query>\n\nSearches for the query in files using fd.\n\nExample:\n  search TODO\n";
        self.io.print(help_message, .Yellow);
    }
};

const Fn = enum {
    Help,
    Encode,
    Decode,
    Invalid,

    fn get(string: []const u8) Fn {
        if (std.mem.eql(u8, string, "encode")) return .Encode;
        if (std.mem.eql(u8, string, "decode")) return .Decode;
        if (std.mem.eql(u8, string, "help") or std.mem.eql(u8, string, "-h")) return .Help;
        return .Invalid;
    }
};
