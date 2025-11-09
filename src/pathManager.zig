//******************************************************************************
//* Path Manager - File & Directory Path Utilities                            *
//*                                                                            *
//* Provides utilities for constructing absolute paths to application         *
//* resources (config files, assets). Ensures paths are relative to the       *
//* executable location for portability.                                      *
//******************************************************************************

const std = @import("std");

/// Retrieves the directory containing the current executable
/// All application paths are relative to this directory for portability
///
/// Returns: Absolute path to executable directory (caller owns memory)
pub fn getExeDir(allocator: std.mem.Allocator) ![]u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const exe_path = try std.fs.selfExePath(&buf);
    const exe_dir = std.fs.path.dirname(exe_path) orelse return error.NoExeDir;
    return allocator.dupe(u8, exe_dir);
}

/// Constructs absolute path to configuration file
/// Config is stored as 'clock.json' in the executable directory
///
/// Returns: Absolute path to clock.json (caller owns memory)
pub fn getConfigPath(allocator: std.mem.Allocator) ![]u8 {
    const exe_dir = try getExeDir(allocator);
    defer allocator.free(exe_dir);
    return std.fs.path.join(allocator, &[_][]const u8{ exe_dir, "clock.json" });
}

/// Constructs absolute path to an asset file in the assets subdirectory
/// Assets are expected in '{exe_dir}/assets/' (fonts, images, etc.)
///
/// Parameters:
///   - filename: Name of asset file (e.g., "RobotoMono-Bold.ttf")
///
/// Returns: Absolute path to asset (caller owns memory)
pub fn getAssetPath(filename: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const exe_dir = try getExeDir(allocator);
    defer allocator.free(exe_dir);
    return std.fs.path.join(allocator, &[_][]const u8{ exe_dir, "assets", filename });
}

test "pathManager basic functionality" {
    const allocator = std.testing.allocator;

    // Test getExeDir
    const exe_dir = try getExeDir(allocator);
    defer allocator.free(exe_dir);
    try std.testing.expect(exe_dir.len > 0);

    // Test getConfigPath
    const config_path = try getConfigPath(allocator);
    defer allocator.free(config_path);
    try std.testing.expect(std.mem.endsWith(u8, config_path, "clock.json"));

    // Test getAssetPath
    const asset_path = try getAssetPath("test.ttf", allocator);
    defer allocator.free(asset_path);
    try std.testing.expect(std.mem.indexOf(u8, asset_path, "assets") != null);
    try std.testing.expect(std.mem.endsWith(u8, asset_path, "test.ttf"));
}
