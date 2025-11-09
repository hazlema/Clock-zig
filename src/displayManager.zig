//******************************************************************************
//* Display Manager - Time Display & Rendering                                 *
//*                                                                            *
//* Handles all time display logic including fetching current time,            *
//* formatting with color codes, parsing segments, and rendering to screen.    *
//* Centralizes display concerns to keep main loop clean.                      *
//******************************************************************************

const std = @import("std");
const rl = @import("raylib");
const fontManager = @import("fontManager.zig");
const screenManager = @import("screenManager.zig");
const c = @cImport({
    @cInclude("time.h");
});

// Color code parsing
const allowed_color_codes = [_]u8{ '0', '1', '2' };

/// Iterator for parsing color-coded text segments
/// Processes strings with embedded color codes (e.g., "|0text|1more")
/// and splits them into segments with associated color indices
const ColorCodeIterator = struct {
    buffer: []const u8,
    index: usize = 0,

    fn init(buffer: []const u8) ColorCodeIterator {
        return .{ .buffer = buffer };
    }

    const Segment = struct {
        text: []const u8,
        color: ?u8, // null means default color, 0-9 for color codes
    };

    /// Advances to the next color-coded segment
    /// Returns: Segment with text and optional color code, or null if exhausted
    fn next(self: *ColorCodeIterator) ?Segment {
        if (self.index >= self.buffer.len) return null;

        // Check if we're starting with a color code
        var color: ?u8 = null;
        if (self.buffer[self.index] == '|' and
            self.index + 1 < self.buffer.len and
            std.mem.indexOfScalar(u8, &allowed_color_codes, self.buffer[self.index + 1]) != null)
        {
            color = self.buffer[self.index + 1] - '0';
            self.index += 2; // Skip "|digit"
        }

        const start = self.index;
        // Scan until we hit another color code or end of buffer
        while (self.index < self.buffer.len) {
            if (self.buffer[self.index] == '|' and
                self.index + 1 < self.buffer.len and
                std.mem.indexOfScalar(u8, &allowed_color_codes, self.buffer[self.index + 1]) != null)
            {
                break;
            }
            self.index += 1;
        }

        // Return segment with text and color (if any)
        if (self.index > start or color != null) {
            return .{ .text = self.buffer[start..self.index], .color = color };
        }

        return null;
    }
};

/// Retrieves current local time using C's time.h library
/// Converts to 12-hour format with AM/PM designation
///
/// Note: Uses libc localtime() because Zig's standard library lacks robust timezone support
///
/// Returns: Anonymous struct with time/date components (12-hour format with AM/PM)
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

/// Renders the current time with color-coded segments (digits, colons, AM/PM)
/// Handles complete time display pipeline:
///   1. Fetches current time via getLocalDateTime()
///   2. Formats with color codes: |0HH|1:|0MM|1:|0SS |2AM/PM
///   3. Auto-scales font to fit window using fontManager
///   4. Parses and renders each segment with ColorCodeIterator
///
/// Color mapping:
///   - |0: White (digits)
///   - |1: Yellow (colons)
///   - |2: Blue (AM/PM)
///
/// Parameters:
///   - font: RayLib font loaded at high resolution for scaling
pub fn drawColoredTime(font: rl.Font) !void {
    // Get current time
    const curDateTime = getLocalDateTime();

    // Format plain time for font sizing (without color codes)
    var plainBuffer: [32]u8 = undefined;
    const plainTime = try std.fmt.bufPrintZ(&plainBuffer, "{d:0>2}:{d:0>2}:{d:0>2} {s}", .{ curDateTime.hours, curDateTime.minutes, curDateTime.seconds, curDateTime.ampm });

    // Format color-coded time: "|0HH|1:|0MM|1:|0SS |2AM/PM"
    // Color codes: |0 = digits, |1 = colons, |2 = AM/PM
    var coloredBuffer: [64]u8 = undefined;
    const coloredTime = try std.fmt.bufPrintZ(&coloredBuffer, "|0{d:0>2}|1:|0{d:0>2}|1:|0{d:0>2} |2{s}", .{ curDateTime.hours, curDateTime.minutes, curDateTime.seconds, curDateTime.ampm });

    // Update font size to fit current window using raw string (without color codes)
    _ = fontManager.update(plainTime, screenManager.screen.width, screenManager.screen.height, font);
    const pos = fontManager.getCenteredPosition(screenManager.screen.width, screenManager.screen.height);

    // Parse and draw color-coded segments
    var iterator = ColorCodeIterator.init(coloredTime);
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
}
