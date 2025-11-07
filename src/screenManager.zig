const std = @import("std");
const rl = @import("raylib");
const full_cfg = @import("configManager.zig");
const cfg = @import("configManager.zig").ScreenConfig;

const ScreenManager = @This();

pub var screen = cfg{};

pub fn init(saved: cfg) void {
    screen = saved;

    // Apply saved settings to the window (window must already be created)
    rl.setWindowSize(screen.width, screen.height);

    // Have to set the monitor first!
    rl.setWindowMonitor(screen.monitor);

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
    rl.setWindowState(rl.ConfigFlags{ .window_undecorated = !screen.border });

    // Setting fn's
    // void setWindowMinSize(int width, int height);               // Set window minimum dimensions (for FLAG_WINDOW_RESIZABLE)
    // void setWindowMaxSize(int width, int height);               // Set window maximum dimensions (for FLAG_WINDOW_RESIZABLE)
    // void setWindowOpacity(float opacity);                       // Set window opacity [0.0f..1.0f]
    // void setWindowFocused(void);
}

pub fn update() ?cfg {
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
