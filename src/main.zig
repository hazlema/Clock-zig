const c = @cImport({
    @cInclude("time.h");
});

const std = @import("std");
const rl = @import("raylib");
const configManager = @import("configManager.zig");
const screenManager = @import("screenManager.zig");
const fontManager = @import("fontManager.zig");
const parse = @import("parse.zig");
const pathManager = @import("pathManager.zig");

const SAVE_DELAY_MS: i32 = 1000;

var projectCfg = configManager{};
var pendingConfigSave = false;
var lastConfigChange: i64 = 0;

fn getLocalDateTime() struct { month: u8, day: u8, year: u32, seconds: u8, minutes: u8, hours: u8, ampm: [:0]const u8 } {
    const now = std.time.timestamp();
    const now_c: c.time_t = @intCast(now);

    // Get local time (uses system timezone)
    const local_time = c.localtime(&now_c);

    // Convert hours to 12-hour format
    var hours = @as(u8, @intCast(local_time.*.tm_hour));
    const ampm = if (hours >= 12) "PM" else "AM";
    hours = if (hours % 12 == 0) 12 else hours % 12;

    return .{
        .seconds = @intCast(local_time.*.tm_sec),
        .minutes = @intCast(local_time.*.tm_min),
        .hours = hours,
        .day = @intCast(local_time.*.tm_mday),
        .month = @intCast(local_time.*.tm_mon + 1), // 0-indexed
        .year = @intCast(local_time.*.tm_year + 1900), // Years since 1900
        .ampm = ampm,
    };
}

fn getFmtTime(buffer: []u8) ![:0]const u8 {
    const curDateTime = getLocalDateTime();
    return try std.fmt.bufPrintZ(buffer, "{d:0>2}:{d:0>2}:{d:0>2} {s}", .{ curDateTime.hours, curDateTime.minutes, curDateTime.seconds, curDateTime.ampm });
}

fn getColorCodedTime(buffer: []u8) ![:0]const u8 {
    const curDateTime = getLocalDateTime();
    // Format: |0HH|1:|0MM|1:|0SS |2AM/PM
    // Color codes: |0 = digits, |1 = colons, |2 = AM/PM
    return try std.fmt.bufPrintZ(buffer, "|0{d:0>2}|1:|0{d:0>2}|1:|0{d:0>2} |2{s}", .{ curDateTime.hours, curDateTime.minutes, curDateTime.seconds, curDateTime.ampm });
}

fn startGui(allocator: std.mem.Allocator) !void {
    // Enable MSAA before window creation for cleaner edges
    rl.setConfigFlags(rl.ConfigFlags{
        .msaa_4x_hint = true,
        .window_transparent = true,
    });

    // Init Raylib / Load custom font at high resolution (256) for sharp scaling
    rl.initWindow(screenManager.screen.width, screenManager.screen.height, "clock");
    rl.setTargetFPS(60);

    // Get absolute path to font asset
    const font_path = try pathManager.getAssetPath("RobotoMonoNerdFont-Bold.ttf", allocator);
    defer allocator.free(font_path);

    // Create null-terminated string for Raylib
    const font_path_z = try allocator.dupeZ(u8, font_path);
    defer allocator.free(font_path_z);

    const font = try rl.loadFontEx(font_path_z, 256, null);

    // Defer order is backwards (FILO)
    // If you reverse these, onClose will be a segfault
    defer {
        // Save config before closing if there are pending changes
        if (pendingConfigSave) {
            _ = projectCfg.save(allocator) catch {};
            std.debug.print("[SAVE]: Final save on exit\n", .{});
        }
        rl.closeWindow();
    }
    defer rl.unloadFont(font); // Font unloads before window closes

    // Point filtering for crisp pixel-perfect text
    rl.setTextureFilter(font.texture, rl.TextureFilter.point);

    // Window Settings
    const undecorated = !projectCfg.screen.border;
    std.debug.print("[WINDOW]: border={}, setting undecorated={}\n", .{ projectCfg.screen.border, undecorated });
    rl.setWindowState(rl.ConfigFlags{
        .window_resizable = true,
        .window_topmost = true,
    });

    // Apply screen configuration to window (position, monitor, size)
    screenManager.init(projectCfg.screen);

    // Clock Loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        // Toggle border on mouse click
        if (rl.isMouseButtonReleased(rl.MouseButton.left)) {
            if (rl.isWindowState(rl.ConfigFlags{ .window_undecorated = true })) {
                rl.clearWindowState(rl.ConfigFlags{ .window_undecorated = true });
                projectCfg.screen.border = true;
            } else {
                rl.setWindowState(rl.ConfigFlags{ .window_undecorated = true });
                projectCfg.screen.border = false;
            }
            pendingConfigSave = true;
            lastConfigChange = std.time.milliTimestamp();
        }

        var timeBuffer: [32]u8 = undefined;
        const timeString = try getFmtTime(&timeBuffer);

        var coloredTimeBuffer: [64]u8 = undefined;
        const coloredTimeString = try getColorCodedTime(&coloredTimeBuffer);

        rl.clearBackground(rl.Color{ .r = 0, .g = 0, .b = 33, .a = 200 });

        // Update font size to fit current window using raw string (without color codes)
        _ = fontManager.update(timeString, screenManager.screen.width, screenManager.screen.height, font);
        const pos = fontManager.getCenteredPosition(screenManager.screen.width, screenManager.screen.height);

        // Parse and draw color-coded segments
        var iterator = parse.ColorCodeIterator.init(coloredTimeString);
        var x_offset: f32 = @floatFromInt(pos.x);
        const y_pos: f32 = @floatFromInt(pos.y);
        const font_size: f32 = @floatFromInt(fontManager.font.size);

        var segmentBuffer: [32]u8 = undefined;
        while (iterator.next()) |segment| {
            // Map color codes to actual colors
            const color = switch (segment.color orelse 0) {
                0 => rl.Color.white,
                1 => rl.Color.yellow,
                2 => rl.Color.blue,
                else => rl.Color.white,
            };

            // Create null-terminated string for this segment
            const segment_text = try std.fmt.bufPrintZ(&segmentBuffer, "{s}", .{segment.text});

            // Draw this segment
            rl.drawTextEx(font, segment_text, .{ .x = x_offset, .y = y_pos }, font_size, 1.0, color);

            // Advance x position for next segment
            const text_width = rl.measureTextEx(font, segment_text, font_size, 1.0);
            x_offset += text_width.x;
        }

        // Check if screen config changed
        const screenChanged = screenManager.update();
        if (screenChanged) |newScreen| {
            projectCfg.screen = newScreen;
            pendingConfigSave = true;
            lastConfigChange = std.time.milliTimestamp();
        }

        // Debounced save: only save if 1 second passed since last change
        if (pendingConfigSave) {
            const timeSinceChange = std.time.milliTimestamp() - lastConfigChange;
            if (timeSinceChange >= SAVE_DELAY_MS) {
                _ = try projectCfg.save(allocator);
                pendingConfigSave = false;
                std.debug.print("[SAVE]: Config saved after {d}ms delay\n", .{timeSinceChange});
            }
        }
    }
}

pub fn main() !void {
    // Memory & allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    std.debug.print("Clock v.01 - zig + RayLib, Author: Frosty\n", .{});

    // Load config (from file if exists, otherwise use defaults)
    projectCfg = try projectCfg.load(allocator);
    std.debug.print("[CONFIG]: border={}\n", .{projectCfg.screen.border});
    try startGui(allocator);
}
