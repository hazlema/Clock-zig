# Clock Project TODO

## High Priority
- [X] Add config loading on startup
  - Check if clock.json exists
  - Parse JSON and load saved window position/size/monitor
  - Fall back to defaults if file doesn't exist or is invalid
- [x] Add defaults
- [X] Add absolute app path for the cfg
- [X] Add absolute app path for the assets loader (fonts)

## Features to Add
- [X] Borderless + transparent mode (click to toggle)
  - Remove window decorations
  - Set window transparency/opacity
  - Blend clock into desktop background
  - Maybe add keybind or click handler to toggle

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

