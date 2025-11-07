# Agent Guidelines for Clock Project

## installed zig version: 0.16

## Build Commands
- Build: `zig build`
- Run: `zig build run`
- Test all: `zig build test`
- Test single file: `zig test src/main.zig --dep raylib` (requires proper dependency setup)

## MCP
- **use Zig-docs MCP Server**: local MCP server should have the same docs as the current zig install

## Code Style
- **Imports**: Standard library first (`std`), then C imports (`@cImport`), then third-party (`raylib`)
- **Naming**: camelCase for functions/variables, PascalCase for types (e.g., `TextSegment`), SCREAMING_SNAKE_CASE for constants
- **Types**: Prefer explicit types, use slices (`[]const u8`) over pointers, use `@intCast` for conversions
- **Error handling**: Use `!` for error unions, `try` for error propagation, `defer` for cleanup
- **Memory**: Use allocators explicitly (e.g., `std.heap.GeneralPurposeAllocator`), always `defer` cleanup
- **Formatting**: Run `zig fmt` before committing, use 4-space indentation
- **Comments**: Use `//` for line comments, `//!` for doc comments at top of files
- **Structs**: Define fields with types, use struct literals with `.{ .field = value }` syntax
- **C interop**: Use `@cImport` for C headers, `@intCast` for C type conversions

## Project-Specific Notes
- Uses Raylib via `raylib_zig` dependency (devel branch)
- Minimum Zig version: 0.16.0-dev.932+6568f0f75
- Main executable: `clock` (GUI clock application with time display)
