//******************************************************************************
//* Config Manager - Configuration Persistence                                 *
//*                                                                            *
//* Manages loading and saving application configuration to JSON file.         *
//* Handles screen settings (size, position, monitor, border) with             *
//* debounced auto-save to prevent excessive disk writes.                      *
//******************************************************************************

const std = @import("std");
const rl = @import("raylib");
const pathManager = @import("pathManager.zig");

const ConfigManager = @This();

pub const ScreenConfig = struct {
    height: i32 = 100,
    width: i32 = 300,
    monitor: i32 = 0,
    position: rl.Vector2 = .{ .x = 0, .y = 0 },
    border: bool = true,
    needs_centering: bool = false,
    suspended: bool = false,

    pub fn jsonStringify(self: ScreenConfig, jw: anytype) !void {
        try jw.beginObject();
        try jw.objectField("height");
        try jw.write(self.height);
        try jw.objectField("width");
        try jw.write(self.width);
        try jw.objectField("monitor");
        try jw.write(self.monitor);
        try jw.objectField("position");
        try jw.write(self.position);
        try jw.objectField("border");
        try jw.write(self.border);
        try jw.endObject();
    }
};

version: f32 = 1.0,
screen: ScreenConfig = .{},

pub fn load(self: *ConfigManager, allocator: std.mem.Allocator) !ConfigManager {
    // Get absolute path to config file
    const config_path = try pathManager.getConfigPath(allocator);
    defer allocator.free(config_path);

    // Try to read the file, return defaults if it doesn't exist
    const contents = std.fs.cwd().readFileAlloc(config_path, allocator, std.Io.Limit.limited(1024 * 1024)) catch {
        // File doesn't exist, return current defaults
        std.debug.print("[CONFIG]: No config found at {s}, using defaults\n", .{config_path});
        self.screen.monitor = 0;
        self.screen.height = 100;
        self.screen.width = 300;
        self.screen.position.x = 0;
        self.screen.position.y = 0;
        self.screen.border = true;
        self.screen.needs_centering = true; // Flag for screenManager to center it
        self.screen.suspended = false; // Flag for screenManager to center it
		
        return self.*;
    };
    defer allocator.free(contents);

    // Parse JSON
    const parsed = try std.json.parseFromSlice(ConfigManager, allocator, contents, .{});
    defer parsed.deinit();

    std.debug.print("[CONFIG]: Loaded from {s}\n", .{config_path});
    return parsed.value;
}

pub fn serialize(self: *ConfigManager, allocator: std.mem.Allocator) ![]u8 {
    var out = std.Io.Writer.Allocating.init(allocator);
    errdefer out.deinit();
    try std.json.Stringify.value(self.*, .{ .whitespace = .indent_2 }, &out.writer);
    return out.toOwnedSlice();
}

pub fn save(self: *ConfigManager, allocator: std.mem.Allocator) !bool {
    const json = try self.serialize(allocator);
    defer allocator.free(json);

    // Get absolute path to config file
    const config_path = try pathManager.getConfigPath(allocator);
    defer allocator.free(config_path);

    const file = try std.fs.cwd().createFile(config_path, .{});
    defer file.close();

    try file.writeAll(json);
    std.debug.print("[SAVE]: Config saved to {s}\n", .{config_path});
    return true;
}
