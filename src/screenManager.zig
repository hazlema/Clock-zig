//******************************************************************************
//* Screen Manager - Window & Display Management                              *
//*                                                                            *
//* Manages window properties including size, position, monitor placement,    *
//* borders, and window flags. Tracks changes to screen state and handles     *
//* window centering and multi-monitor support.                               *
//******************************************************************************

const std = @import("std");
const rl = @import("raylib");
const full_cfg = @import("configManager.zig");
const cfg = @import("configManager.zig").ScreenConfig;

const ScreenManager = @This();

const WINDOW_CHROME_HEIGHT: i32 = 35; // Typical Linux window header/titlebar height

pub var screen = cfg{};

/// Initializes window flags that MUST be set before window creation
/// Sets MSAA 4x antialiasing and window transparency
///
/// CRITICAL: Must be called BEFORE rl.initWindow() or flags won't take effect
pub fn preInit() void {
    rl.setConfigFlags(rl.ConfigFlags{
        .msaa_4x_hint = true,
        .window_transparent = true,
    });
}

/// Applies all window configuration from saved config
/// Handles monitor selection, border state transitions, size adjustments, and positioning
/// If needs_centering flag is set (first run), centers window on target monitor
///
/// CRITICAL: Must be called AFTER rl.initWindow()
///
/// Parameters:
///   - saved: ScreenConfig with desired window settings
pub fn init(saved: cfg) void {
    screen = saved;

    // Set window properties
    setResizable(true);
    setTopmost(true);

    // Have to set the monitor first!
    rl.setWindowMonitor(screen.monitor);

    // Check current border state (window is created with border by default)
    const currently_has_border = !(rl.isWindowState(rl.ConfigFlags{ .window_undecorated = true }));

    // Calculate the correct initial size based on border state transition
    var initial_height = screen.height;
    if (currently_has_border and !screen.border) {
        // Window has border now, but config wants borderless
        // The saved height is for borderless, so we need to account for chrome removal
        initial_height = screen.height - WINDOW_CHROME_HEIGHT;
    } else if (!currently_has_border and screen.border) {
        // Window is borderless now, but config wants border
        // The saved height is for bordered, so we need to account for chrome addition
        initial_height = screen.height + WINDOW_CHROME_HEIGHT;
    }

    // Apply the adjusted size
    rl.setWindowSize(screen.width, initial_height);

    // Set border state BEFORE positioning to avoid position shifts
    // Use internal version to avoid triggering resize logic during init
    if (screen.border) {
        rl.clearWindowState(rl.ConfigFlags{ .window_undecorated = true });
    } else {
        rl.setWindowState(rl.ConfigFlags{ .window_undecorated = true });
    }

    // Center the window if needs_centering flag is set (first run with no config)
    if (screen.needs_centering) {
        const monitor_width = rl.getMonitorWidth(screen.monitor);
        const monitor_height = rl.getMonitorHeight(screen.monitor);
        const monitor_pos = rl.getMonitorPosition(screen.monitor);

        // Calculate center position: monitor_pos + (monitor_size - window_size) / 2
        screen.position.x = monitor_pos.x + @as(f32, @floatFromInt(@divTrunc(monitor_width - screen.width, 2)));
        screen.position.y = monitor_pos.y + @as(f32, @floatFromInt(@divTrunc(monitor_height - screen.height, 2)));
        screen.needs_centering = false; // Clear the flag

        std.debug.print("[SCREEN]: Centering on monitor {d} at ({d}, {d})\n", .{ screen.monitor, screen.position.x, screen.position.y });
    }

    rl.setWindowPosition(@intFromFloat(screen.position.x), @intFromFloat(screen.position.y));
}

/// Polls current window state and detects changes
/// Compares current window properties (size, position, monitor, border) against cached state
/// Respects suspended flag to prevent updates during drag operations
///
/// Returns: Updated ScreenConfig if any property changed, null otherwise
pub fn update() ?cfg {
	if (screen.suspended == true) {
		return null;
	}

    const w: i32 = rl.getRenderWidth();
    const h: i32 = rl.getRenderHeight();
    const pos: rl.Vector2 = rl.getWindowPosition();
    const monitor: i32 = rl.getCurrentMonitor();
    const border: bool = !(rl.isWindowState(rl.ConfigFlags{ .window_undecorated = true }));

    if (w != screen.width or h != screen.height or pos.x != screen.position.x or pos.y != screen.position.y or monitor != screen.monitor or border != screen.border) {
        screen.width = w;
        screen.height = h;
        screen.position = pos;
        screen.monitor = monitor;
        screen.border = border;

        //std.debug.print("[UPDATES]: Render area: {d}x{d}, Monitor: {d}, Position: {any}\n", .{ screen.width, screen.height, screen.monitor, screen.position });
        return screen;
    }

    // nothing changed
    return null;
}

/// Sets window border state with automatic height compensation
/// Adjusts window height by ±35px (WINDOW_CHROME_HEIGHT) to maintain consistent content area
///
/// Height adjustment logic:
///   - Adding border: Subtracts 35px (content area shrinks, chrome added)
///   - Removing border: Adds 35px (content area expands, chrome removed)
///
/// This ensures click detection matches visual bounds regardless of border state
///
/// Parameters:
///   - has_border: true to show titlebar/border, false for borderless
pub fn setBorder(has_border: bool) void {
    const is_currently_undecorated = rl.isWindowState(rl.ConfigFlags{ .window_undecorated = true });
    const currently_has_border = !is_currently_undecorated;

    // Only adjust if state is actually changing
    if (currently_has_border == has_border) {
        return;
    }

    const current_width = rl.getScreenWidth();
    const current_height = rl.getScreenHeight();

    if (has_border) {
        // Going from borderless to bordered - shrink height to compensate for chrome
        rl.clearWindowState(rl.ConfigFlags{ .window_undecorated = true });
        rl.setWindowSize(current_width, current_height - WINDOW_CHROME_HEIGHT);
    } else {
        // Going from bordered to borderless - grow height to maintain content area
        rl.setWindowState(rl.ConfigFlags{ .window_undecorated = true });
        rl.setWindowSize(current_width, current_height + WINDOW_CHROME_HEIGHT);
    }

    screen.border = has_border;
}

/// Toggles window border on/off
/// Convenience wrapper around setBorder() that flips current state
pub fn toggleBorder() void {
    setBorder(!screen.border);
}

/// Controls whether window stays on top of other windows
/// Useful for clock/widget applications that should remain visible
///
/// Parameters:
///   - enabled: true to keep window on top, false for normal layering
pub fn setTopmost(enabled: bool) void {
    if (enabled) {
        rl.setWindowState(rl.ConfigFlags{ .window_topmost = true });
    } else {
        rl.clearWindowState(rl.ConfigFlags{ .window_topmost = true });
    }
}

/// Controls whether user can resize window by dragging edges
///
/// Parameters:
///   - enabled: true to allow resizing, false to lock size
pub fn setResizable(enabled: bool) void {
    if (enabled) {
        rl.setWindowState(rl.ConfigFlags{ .window_resizable = true });
    } else {
        rl.clearWindowState(rl.ConfigFlags{ .window_resizable = true });
    }
}
