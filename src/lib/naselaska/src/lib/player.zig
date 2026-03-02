pub const Player = struct {
    name: []const u8,
    // Static Methods
    pub fn init(name: []const u8) Player {
        return Player{ .name = name };
    }
};
