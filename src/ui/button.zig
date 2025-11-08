//******************************************************************************
//* UI/Button - Clickable UI Button System                                    *
//*                                                                            *
//* Provides button structs and manager for creating interactive UI elements. *
//* Handles hover states, click detection, and rendering. Includes            *
//* ButtonManager for tracking multiple buttons efficiently.                  *
//******************************************************************************
//!
//! Usage example:
//!
//! const button = @import("button.zig");
//!
//! // Create actual button structs
//! var settings_btn = button.Button{
//!     .rect = .{ .x = 10, .y = 10, .width = 100, .height = 40 },
//!     .label = "Settings",
//! };
//!
//! var close_btn = button.Button{
//!     .rect = .{ .x = 120, .y = 10, .width = 100, .height = 40 },
//!     .label = "Close",
//! };
//!
//! // Create button manager to track multiple buttons
//! var btn_mgr = button.ButtonManager.init(allocator);
//! defer btn_mgr.deinit();
//!
//! // Add buttons (stores pointers, not copies)
//! try btn_mgr.add(&settings_btn);
//! try btn_mgr.add(&close_btn);
//!
//! // In your main loop:
//! while (!rl.windowShouldClose()) {
//!     rl.beginDrawing();
//!     defer rl.endDrawing();
//!
//!     // Update all buttons with current mouse position
//!     const mouse_pos = rl.getMousePosition();
//!     btn_mgr.updateAll(mouse_pos);
//!
//!     // Draw all buttons (use drawAll() for default font, or drawAllEx() for custom font)
//!     btn_mgr.drawAll();
//!     // btn_mgr.drawAllEx(custom_font, 24.0);
//!
//!     // Check for clicks
//!     if (btn_mgr.getClicked()) |clicked| {
//!         if (std.mem.eql(u8, clicked.label, "Settings")) {
//!             // Handle settings button click
//!         } else if (std.mem.eql(u8, clicked.label, "Close")) {
//!             // Handle close button click
//!         }
//!     }
//!
//!     // Buttons can be moved directly - the pointer in the manager stays valid
//!     settings_btn.rect.x = 150;  // Button moves!
//! }

const std = @import("std");
const rl = @import("raylib");

/// A clickable button with hover and press states
pub const Button = struct {
    rect: rl.Rectangle,
    label: []const u8,
    is_hovered: bool = false,
    is_pressed: bool = false,

    /// Check if a point (like mouse position) is inside the button
    pub fn contains(self: Button, point: rl.Vector2) bool {
        return rl.checkCollisionPointRec(point, self.rect);
    }

    /// Update button state based on mouse position and clicks
    pub fn update(self: *Button, mouse_pos: rl.Vector2) void {
        self.is_hovered = self.contains(mouse_pos);

        if (self.is_hovered and rl.isMouseButtonPressed(rl.MouseButton.left)) {
            self.is_pressed = true;
        } else {
            self.is_pressed = false;
        }
    }

    /// Draw the button with appropriate visual state
    pub fn draw(self: Button) void {
        // Choose color based on state
        const color = if (self.is_pressed)
            rl.Color.dark_gray
        else if (self.is_hovered)
            rl.Color.light_gray
        else
            rl.Color.gray;

        // Draw filled rectangle
        rl.drawRectangleRec(self.rect, color);

        // Draw border
        rl.drawRectangleLinesEx(self.rect, 2, rl.Color.black);

        // Draw centered text
        const text_size = rl.measureText(self.label, 20);
        const text_x: i32 = @intFromFloat(self.rect.x + (self.rect.width - @as(f32, @floatFromInt(text_size))) / 2);
        const text_y: i32 = @intFromFloat(self.rect.y + (self.rect.height - 20) / 2);

        const text_color = if (self.is_pressed or self.is_hovered)
            rl.Color.black
        else
            rl.Color.white;

        rl.drawText(self.label, text_x, text_y, 20, text_color);
    }

    /// Draw the button with a custom font
    pub fn drawEx(self: Button, font: rl.Font, font_size: f32) void {
        // Choose color based on state
        const color = if (self.is_pressed)
            rl.Color.dark_gray
        else if (self.is_hovered)
            rl.Color.light_gray
        else
            rl.Color.gray;

        // Draw filled rectangle
        rl.drawRectangleRec(self.rect, color);

        // Draw border
        rl.drawRectangleLinesEx(self.rect, 2, rl.Color.black);

        // Measure and center text
        const text_size = rl.measureTextEx(font, self.label, font_size, 1.0);
        const text_x = self.rect.x + (self.rect.width - text_size.x) / 2;
        const text_y = self.rect.y + (self.rect.height - text_size.y) / 2;

        const text_color = if (self.is_pressed or self.is_hovered)
            rl.Color.black
        else
            rl.Color.white;

        rl.drawTextEx(font, self.label, .{ .x = text_x, .y = text_y }, font_size, 1.0, text_color);
    }
};

/// Manager for tracking multiple buttons
pub const ButtonManager = struct {
    buttons: std.ArrayList(*Button),

    pub fn init(allocator: std.mem.Allocator) ButtonManager {
        return .{
            .buttons = std.ArrayList(*Button).init(allocator),
        };
    }

    pub fn deinit(self: *ButtonManager) void {
        self.buttons.deinit();
    }

    /// Add a button to be tracked (stores pointer, not copy)
    pub fn add(self: *ButtonManager, button: *Button) !void {
        try self.buttons.append(button);
    }

    /// Update all buttons with current mouse position
    pub fn updateAll(self: *ButtonManager, mouse_pos: rl.Vector2) void {
        for (self.buttons.items) |button| {
            button.update(mouse_pos);
        }
    }

    /// Draw all buttons
    pub fn drawAll(self: ButtonManager) void {
        for (self.buttons.items) |button| {
            button.draw();
        }
    }

    /// Draw all buttons with custom font
    pub fn drawAllEx(self: ButtonManager, font: rl.Font, font_size: f32) void {
        for (self.buttons.items) |button| {
            button.drawEx(font, font_size);
        }
    }

    /// Check if any button was clicked and return its pointer
    pub fn getClicked(self: ButtonManager) ?*Button {
        for (self.buttons.items) |button| {
            if (button.is_pressed) {
                return button;
            }
        }
        return null;
    }
};
