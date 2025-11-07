const std = @import("std");
const rl = @import("raylib");

const FontManager = @This();

pub const FontInfo = struct {
    size: i32 = 42,
    measuredWidth: i32 = 0,
    measuredHeight: i32 = 0,
};

pub var font = FontInfo{};

const PADDING: i32 = 10;

/// Find the optimal font size that fits within the given box dimensions
/// Returns the calculated font size
pub fn update(text: [:0]const u8, boxWidth: i32, boxHeight: i32, customFont: rl.Font) i32 {
    const maxWidth = boxWidth - (PADDING * 2);
    const maxHeight = boxHeight - (PADDING * 2);

    // Start with height-based size
    var fontSize: f32 = @floatFromInt(maxHeight);

    // Reduce until text fits within width
    while (fontSize > 1.0) {
        const textSize = rl.measureTextEx(customFont, text, fontSize, 1.0);

        if (@as(i32, @intFromFloat(textSize.x)) <= maxWidth) {
            // Found a size that fits!
            font.size = @intFromFloat(fontSize);
            font.measuredWidth = @intFromFloat(textSize.x);
            font.measuredHeight = @intFromFloat(textSize.y);
            return font.size;
        }

        fontSize -= 1.0;
    }

    // Fallback to minimum size
    font.size = 1;
    const textSize = rl.measureTextEx(customFont, text, 1.0, 1.0);
    font.measuredWidth = @intFromFloat(textSize.x);
    font.measuredHeight = @intFromFloat(textSize.y);
    return 1;
}

/// Calculate centered position for text with current font
pub fn getCenteredPosition(boxWidth: i32, boxHeight: i32) struct { x: i32, y: i32 } {
    const x = @divTrunc(boxWidth - font.measuredWidth, 2);
    const y = @divTrunc(boxHeight - font.measuredHeight, 2);
    return .{ .x = x, .y = y };
}
