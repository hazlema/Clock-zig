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
var isDragging = false;
var ignoreNextRelease = false;
var dragOffset: rl.Vector2 = undefined; // Offset from window top-left to initial click position
var dragStartWindowPos: rl.Vector2 = undefined; // Window position when drag started

fn inputHandler() void {
    // Mouse button pressed - calculate the offset from window top-left to click position
    if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
        const mouseLocal = rl.getMousePosition();
        dragStartWindowPos = rl.getWindowPosition();
        // Store the offset from window's top-left corner to where we clicked
        dragOffset = mouseLocal;
        isDragging = false;
        ignoreNextRelease = false;
    }

    // Mouse button held down - check for drag movement (only in borderless mode)
    if (rl.isMouseButtonDown(rl.MouseButton.left) and !screenManager.screen.border) {
        const mouseLocal = rl.getMousePosition();

        const dragThreshold: f32 = 5.0;

        // Start dragging if moved beyond threshold
        if (!isDragging) {
            const totalDelta = rl.Vector2{
                .x = mouseLocal.x - dragOffset.x,
                .y = mouseLocal.y - dragOffset.y,
            };
            if (@abs(totalDelta.x) > dragThreshold or @abs(totalDelta.y) > dragThreshold) {
                isDragging = true;
            }
        }

        // Move window during drag - position window so click point stays under cursor
        if (isDragging) {
            // Calculate the delta from where the drag started
            const mouseDelta = rl.Vector2{
                .x = mouseLocal.x - dragOffset.x,
                .y = mouseLocal.y - dragOffset.y,
            };

            // Position window based on original position plus mouse movement
            const newPos = rl.Vector2{
                .x = dragStartWindowPos.x + mouseDelta.x,
                .y = dragStartWindowPos.y + mouseDelta.y,
            };

            rl.setWindowPosition(@intFromFloat(newPos.x), @intFromFloat(newPos.y));
            ignoreNextRelease = true;
        }
    }

    // Mouse button released - either finish drag or toggle border
    if (rl.isMouseButtonReleased(rl.MouseButton.left)) {
        if (ignoreNextRelease) {
            // Drag completed - manually update screen position since we blocked screenManager.update()
            ignoreNextRelease = false;
            isDragging = false;
            screenManager.screen.position = rl.getWindowPosition();
            projectCfg.screen = screenManager.screen;
            pendingConfigSave = true;
            lastConfigChange = std.time.milliTimestamp();
        } else {
            // Regular click - toggle border
            screenManager.toggleBorder();
            projectCfg.screen = screenManager.screen;
            pendingConfigSave = true;
            lastConfigChange = std.time.milliTimestamp();
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

        // Check if screen config changed (but not during drag to avoid feedback loops)
        if (!isDragging) {
            const screenChanged = screenManager.update();
            if (screenChanged) |newScreen| {
                projectCfg.screen = newScreen;
                pendingConfigSave = true;
                lastConfigChange = std.time.milliTimestamp();
            }
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
