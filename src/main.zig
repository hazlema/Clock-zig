//******************************************************************************
//* Desktop Clock - zig 0.16 + RayLib, Author: Frosty                          *
//*                                                                            *
//* Main entry point and application loop. Handles window initialization,     *
//* input events, config management, and orchestrates the display manager     *
//* to render the clock.                                                      *
//******************************************************************************

const version = "0.1";

const std = @import("std");
const rl = @import("raylib");
const configManager = @import("configManager.zig");
const screenManager = @import("screenManager.zig");
const fontManager = @import("fontManager.zig");
const pathManager = @import("pathManager.zig");
const displayManager = @import("displayManager.zig");
const SAVE_DELAY_MS: i32 = 1000;

var projectCfg = configManager{};
var pendingConfigSave = false;
var lastConfigChange: i64 = 0;

// Drag-to-move state tracking
var dragOffset: ?rl.Vector2 = null; // Where in the window we clicked (window-space)
var lastDragMousePos: ?rl.Vector2 = null; // Last mouse position during drag to detect movement

fn inputHandler() void {
    const mousePosition = rl.getMousePosition();

    // User clicks the clock window - calculate offset
    if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
        if (dragOffset == null) {
            // dragOffset is where we clicked within the window
            dragOffset = mousePosition;
            lastDragMousePos = mousePosition;
            screenManager.screen.suspended = true;
            std.debug.print("mousedown\n", .{});
        }
    }

    if (rl.isMouseButtonReleased(rl.MouseButton.left) and dragOffset != null) {
        lastDragMousePos = null;
        defer {
            screenManager.screen.suspended = false;
        }

        // Was not a drag - check if mouse position didn't change from click start
        if (dragOffset) |clickPos| {
            const clickX: i32 = @intFromFloat(@floor(clickPos.x));
            const clickY: i32 = @intFromFloat(@floor(clickPos.y));

            const mouseX: i32 = @intFromFloat(@floor(mousePosition.x));
            const mouseY: i32 = @intFromFloat(@floor(mousePosition.y));

            if (clickX == mouseX and clickY == mouseY) {
                screenManager.toggleBorder();
            }
        }

        dragOffset = null;
        std.debug.print("mouseup\n", .{});
    }

    if (dragOffset) |offset| {
        // Only update if mouse actually moved to prevent jitter
        if (lastDragMousePos) |lastPos| {
            if (lastPos.x != mousePosition.x or lastPos.y != mousePosition.y) {
                // Get the actual current window position to convert mouse coords properly
                const actualWindowPos = rl.getWindowPosition();
                // Convert mouse from window-space to screen-space
                const mouseScreenPos = mousePosition.add(actualWindowPos);
                // Calculate where window should be (mouse screen pos - where we clicked in window)
                const newWindowPos = mouseScreenPos.subtract(offset);
                // Move the window
                rl.setWindowPosition(@intFromFloat(newWindowPos.x), @intFromFloat(newWindowPos.y));
                // Update last position
                lastDragMousePos = mousePosition;
            }
        }
    }
}

fn startGui(allocator: std.mem.Allocator) !void {
    // Pre-window initialization (MSAA, transparency must be set before window creation)
    screenManager.preInit();

    // Init Raylib / Load custom font at high resolution (256) for sharp scaling
    rl.initWindow(screenManager.screen.width, screenManager.screen.height, "clock");
    rl.setTargetFPS(60);

    // Get absolute path to font asset
    //const font_path = try pathManager.getAssetPath("KenneyFuture.ttf", allocator);
    //const font_path = try pathManager.getAssetPath("RobotoMono-Bold.ttf", allocator);
    const font_path = try pathManager.getAssetPath("Cousine-Bold.ttf", allocator);
    defer allocator.free(font_path);

    // Create null-terminated string for Raylib
    const font_path_z = try allocator.dupeZ(u8, font_path);
    defer allocator.free(font_path_z);

    // Load Font / Point filtering for crisp pixel-perfect text
    const font = try rl.loadFontEx(font_path_z, 512, null);
    rl.setTextureFilter(font.texture, rl.TextureFilter.point);

    // Defer order is backwards (FILO) - If you reverse these, onClose will be a segfault
    defer {
        // Save config before closing if there are pending changes
        if (pendingConfigSave) {
            _ = projectCfg.save(allocator) catch {};
            std.debug.print("[SAVE]: Final save on exit\n", .{});
        }
        rl.closeWindow();
    }
    defer rl.unloadFont(font); // Font unloads before window closes

    // Apply all window settings from config (position, monitor, size, border, etc.)
    screenManager.init(projectCfg.screen);

    // Clock Loop
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        inputHandler();
        rl.clearBackground(rl.Color{ .r = 0, .g = 0, .b = 33, .a = 200 });

        // Draw the colored time (handles formatting, parsing, and rendering)
        try displayManager.drawColoredTime(font);

        // Check if screen config changed (suspended during drag via screenManager.screen.suspended)
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
    // set mem
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load config / run GUI
    std.debug.print("Clock v{s} - zig 0.16 + RayLib, Author: Frosty\n", .{version});
    projectCfg = try projectCfg.load(allocator);
    try startGui(allocator);
}
