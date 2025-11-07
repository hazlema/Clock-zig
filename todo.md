# Clock Project TODO

## High Priority
- [X] Add config loading on startup
  - Check if clock.json exists
  - Parse JSON and load saved window position/size/monitor
  - Fall back to defaults if file doesn't exist or is invalid
- [ ] Add defaults
- [X] Add absolute app path for the cfg
- [X] Add absolute app path for the assets loader (fonts)

## Features to Add
- [X] Borderless + transparent mode (click to toggle)
  - 75% complete
  - Remove window decorations
  - Set window transparency/opacity
  - Blend clock into desktop background
  - Maybe add keybind or click handler to toggle
- [ ] Borderless sixzze fix

- [ ] Color-coded text using parse.zig
  - Wire up ColorCodeIterator
  - Map color codes (0-9) to Raylib colors
  - Render each segment with its color
  - Track X position while drawing segments

- [ ] Theme system
  - Store color schemes in configManager
  - Font selection
  - Background color/transparency
  - Save/load themes from config

## Future Ideas
- [ ] Alarm system
- [ ] Multiple time zones
- [ ] Shader effects / animations
- [ ] Context menu for settings
- [ ] Settings screen/dialog
- [ ] Custom date formats
- [ ] Different clock faces (analog, binary, etc.)

## Polish
- [ ] Better error handling on file I/O
- [ ] Validate loaded config data
- [ ] Add version migration for config file format changes

## Refactor - ViewManager System
- [ ] Rename parse.zig to viewManager.zig
- [ ] Design ViewManager struct
  - [ ] Add ViewType enum (clock, date, stopwatch, countdown)
  - [ ] Add current_view state tracking
  - [ ] Add previous_view for animation reference
  - [ ] Add animation_progress (0.0 to 1.0)
  - [ ] Add is_animating boolean flag
- [ ] Migrate ColorCodeIterator to viewManager.zig
- [ ] Implement clock view rendering
  - [ ] Move getColorCodedTime logic into view
  - [ ] Return formatted time string with color codes
- [ ] Implement date view rendering
  - [ ] Format date with color codes (month/day/year)
  - [ ] Handle different date formats
- [ ] Implement stopwatch view
  - [ ] Track elapsed time
  - [ ] Start/stop/reset controls
  - [ ] Format stopwatch display
- [ ] Implement countdown view
  - [ ] Set target time
  - [ ] Calculate remaining time
  - [ ] Format countdown display
- [ ] Add view switching logic
  - [ ] switchView() method to change views
  - [ ] Trigger animation on view change
  - [ ] Store previous view for slide-out direction
- [ ] Implement slide animation system
  - [ ] Update animation progress based on delta_time
  - [ ] Calculate slide offset for smooth transitions
  - [ ] Interpolate between previous and current view
  - [ ] Support slide directions (left/right/up/down)
- [ ] Add keyboard shortcuts for view switching
  - [ ] '1' key = clock view
  - [ ] '2' key = date view
  - [ ] '3' key = stopwatch view
  - [ ] '4' key = countdown view
  - [ ] Tab = cycle through views
- [ ] Update main.zig to use ViewManager
  - [ ] Replace direct time rendering with viewManager.render()
  - [ ] Pass delta_time to viewManager.update()
  - [ ] Handle keyboard input for view switching
