//******************************************************************************
//* Font Manager - Dynamic Font Sizing & Layout                                *
//*                                                                            *
//* Calculates optimal font size to fit text within window bounds and          *
//* provides centered positioning. Ensures text scales dynamically with        *
//* window resizing while maintaining readability.                             *
//******************************************************************************

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

/// Calculates optimal font size to fit text within specified dimensions
/// Uses iterative reduction from height-based starting size until text fits width constraint
/// Caches measured dimensions for subsequent getCenteredPosition() calls
///
/// Algorithm:
///   1. Start with font size = (boxHeight - padding)
///   2. Measure text width at current size
///   3. If fits within boxWidth, done; otherwise reduce size by 1 and retry
///
/// Parameters:
///   - text: Null-terminated string to measure (should be plain text without color codes)
///   - boxWidth: Maximum available width in pixels
///   - boxHeight: Maximum available height in pixels
///   - customFont: RayLib font to use for measurement
///
/// Returns: Calculated font size in pixels
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

/// Calculates centered position for text using cached measurements from update()
/// Centers both horizontally and vertically within the specified box
///
/// Note: Must call update() first to populate font.measuredWidth/Height
///
/// Parameters:
///   - boxWidth: Container width in pixels
///   - boxHeight: Container height in pixels
///
/// Returns: Top-left corner coordinates for centered text
pub fn getCenteredPosition(boxWidth: i32, boxHeight: i32) struct { x: i32, y: i32 } {
    const x = @divTrunc(boxWidth - font.measuredWidth, 2);
    const y = @divTrunc(boxHeight - font.measuredHeight, 2);
    return .{ .x = x, .y = y };
}
