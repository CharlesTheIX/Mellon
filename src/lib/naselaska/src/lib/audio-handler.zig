const std = @import("std");
const rl = @import("raylib");

pub const AudioType = enum { Sound, Music };

pub const AudioHandler = struct {
    allocator: std.mem.Allocator,
    music: std.StringHashMap(rl.Music),
    sounds: std.StringHashMap(rl.Sound),

    pub fn init(allocator: std.mem.Allocator) AudioHandler {
        rl.initAudioDevice();
        return AudioHandler{
            .allocator = allocator,
            .music = std.StringHashMap(rl.Music).init(allocator),
            .sounds = std.StringHashMap(rl.Sound).init(allocator),
        };
    }

    pub fn deinit(self: *AudioHandler) void {
        var sound_it = self.sounds.valueIterator();
        while (sound_it.next()) |sound| rl.unloadSound(sound.*);
        self.sounds.deinit();
        var music_it = self.music.valueIterator();
        while (music_it.next()) |music| rl.unloadMusicStream(music.*);
        self.music.deinit();
        rl.closeAudioDevice();
    }

    pub fn load(self: *AudioHandler, audio_type: AudioType, key: []const u8, file_path: []const u8) !bool {
        if (self.sounds.contains(key) or self.music.contains(key)) return false;
        const key_copy = try self.allocator.dupe(u8, key);
        const file_path_z = try self.allocator.dupeZ(u8, file_path);
        defer self.allocator.free(file_path_z);
        switch (audio_type) {
            .Sound => {
                const audio = rl.loadSound(file_path_z) catch return false;
                try self.sounds.put(key_copy, audio);
            },
            .Music => {
                const audio = rl.loadMusicStream(file_path_z) catch return false;
                try self.music.put(key_copy, audio);
            },
        }
        return true;
    }

    pub fn unload(self: *AudioHandler, audio_type: AudioType, key: []const u8) bool {
        switch (audio_type) {
            .Sound => {
                if (self.sounds.fetchRemove(key)) |entry| {
                    rl.unloadSound(entry.value);
                    self.allocator.free(entry.key);
                    return true;
                }
            },
            .Music => {
                if (self.music.fetchRemove(key)) |entry| {
                    rl.unloadMusicStream(entry.value);
                    self.allocator.free(entry.key);
                    return true;
                }
            },
        }
        return false;
    }

    pub fn play(self: *AudioHandler, audio_type: AudioType, key: []const u8) bool {
        switch (audio_type) {
            .Sound => {
                if (self.sounds.get(key)) |audio| {
                    rl.playSound(audio);
                    return true;
                }
            },
            .Music => {
                if (self.music.get(key)) |audio| {
                    rl.playMusicStream(audio);
                    return true;
                }
            },
        }
        return false;
    }

    // Raylib music streams must be updated every frame.
    pub fn updateMusicStreams(self: *AudioHandler) void {
        var it = self.music.valueIterator();
        while (it.next()) |audio| rl.updateMusicStream(audio.*);
    }

    pub fn isPlaying(self: *AudioHandler, audio_type: AudioType, key: []const u8) bool {
        switch (audio_type) {
            .Sound => if (self.sounds.get(key)) |audio| return rl.isSoundPlaying(audio),
            .Music => if (self.music.get(key)) |audio| return rl.isMusicStreamPlaying(audio),
        }
        return false;
    }

    pub fn stop(self: *AudioHandler, audio_type: AudioType, key: []const u8) bool {
        switch (audio_type) {
            .Sound => {
                if (self.sounds.get(key)) |audio| {
                    rl.stopSound(audio);
                    return true;
                }
            },
            .Music => {
                if (self.music.get(key)) |audio| {
                    rl.stopMusicStream(audio);
                    return true;
                }
            },
        }
        return false;
    }

    pub fn setVolume(self: *AudioHandler, audio_type: AudioType, key: []const u8, volume: f32) bool {
        switch (audio_type) {
            .Sound => {
                if (self.sounds.get(key)) |audio| {
                    rl.setSoundVolume(audio, volume);
                    return true;
                }
            },
            .Music => {
                if (self.music.get(key)) |audio| {
                    rl.setMusicVolume(audio, volume);
                    return true;
                }
            },
        }
        return false;
    }

    pub fn isLoaded(self: *AudioHandler, audio_type: AudioType, key: []const u8) bool {
        switch (audio_type) {
            .Sound => return self.sounds.contains(key),
            .Music => return self.music.contains(key),
        }
    }

    pub fn count(self: *AudioHandler, audio_type: AudioType) usize {
        switch (audio_type) {
            .Sound => return self.sounds.count(),
            .Music => return self.music.count(),
        }
    }
};
