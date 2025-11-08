# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Build the project
zig build

# Run the clock application
zig build run

# Run tests
zig build test
```

The executable is built to `bin/clock` with assets automatically copied to `bin/assets/`.

## Architecture Overview

This is a desktop clock application built with Zig 0.16 and RayLib. The architecture follows a manager-based pattern where each manager handles a specific domain of responsibility.

### MCP
- **use Zig-docs MCP Server**: local MCP server should have the same docs as the current zig install

### Core Manager System

**main.zig** - Application entry point and main loop
- Owns the config and coordinates all managers
- Handles input (left-click toggles window border)
- Implements debounced auto-save (1 second delay)
- Defer chain ensures proper cleanup order (config save → window close → font unload)

**screenManager.zig** - Window & display management
- Manages window size, position, monitor, borders, and flags
- **Critical: `WINDOW_CHROME_HEIGHT = 35px`** - Linux titlebar height used for border calculations
- `preInit()` must be called BEFORE `rl.initWindow()` (sets MSAA, transparency)
- `init()` must be called AFTER `rl.initWindow()` (applies all config settings)
- `update()` polls window state and returns changes (or null if unchanged)
- **Border toggling logic**: When toggling border state, height is adjusted by ±35px to maintain consistent content area

**configManager.zig** - Configuration persistence
- Loads/saves `clock.json` in executable directory
- `ScreenConfig.needs_centering` is a runtime-only flag (not serialized to JSON)
- First run (no config file) sets `needs_centering=true` which triggers window centering

**displayManager.zig** - Time rendering
- Fetches local time via C's `time.h` (`localtime()`)
- Color-coded format: `"|0HH|1:|0MM|1:|0SS |2AM/PM"` (digits=white, colons=yellow, AM/PM=blue)
- Uses `ColorCodeIterator` to parse color codes and render segments separately

**fontManager.zig** - Dynamic font scaling
- Auto-scales font to fit window size with configurable padding
- Caches last measured text to avoid redundant calculations
- Font loaded at 256pt with point filtering for crisp scaling

**pathManager.zig** - Path resolution
- All paths are relative to executable directory
- Config: `{exe_dir}/clock.json`
- Assets: `{exe_dir}/assets/{filename}`

### Window Border State Management

**Critical for bug fixes**: The window border state transitions have specific height adjustment requirements:

1. **At initialization** (screenManager.init):
   - Window is created with border by default
   - If config wants borderless, must subtract 35px from height BEFORE removing border
   - If config wants border, height is used as-is

2. **During runtime toggle** (screenManager.setBorder):
   - Adding border: subtract 35px (content area becomes smaller)
   - Removing border: add 35px (content area becomes larger)

3. **Why this matters**:
   - With border: `setWindowSize()` sets the content area (total = content + chrome)
   - Without border: `setWindowSize()` sets the total window size
   - Failing to adjust causes misalignment between click detection and visual bounds

### UI System

**ui/button.zig** - Button component system
- `Button` struct: rectangle-based with hover/pressed states
- `ButtonManager`: tracks multiple buttons, handles batch updates/rendering
- Uses RayLib's collision detection (`checkCollisionPointRec`)

## Dependencies

- **Zig 0.16**
- **RayLib** (via `raylib_zig` dependency in build.zig.zon)
- **RobotoMonoNerdFont-Bold.ttf** (must be in assets/)
