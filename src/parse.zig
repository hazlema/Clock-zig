const std = @import("std");

const allowed_color_codes = [_]u8{ '0', '1', '2' };

pub const ColorCodeIterator = struct {
    buffer: []const u8,
    index: usize = 0,

    pub fn init(buffer: []const u8) ColorCodeIterator {
        return .{ .buffer = buffer };
    }

    pub const Segment = struct {
        text: []const u8,
        color: ?u8, // null means default color, 0-9 for color codes
    };

    pub fn next(self: *ColorCodeIterator) ?Segment {
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
// Example usage:
test "parse color codes" {
    const text = "Hello |1Wo|rld|2!|3 Test|9end";
    var it = ColorCodeIterator.init(text);

    while (it.next()) |segment| {
        std.debug.print("text: {s}, Color: {any}\n", .{ segment.text, segment.color });
    }
}
