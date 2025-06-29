const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const token_module = @import("token.zig");
const Token = token_module.Token;
const TokenWithPosition = token_module.TokenWithPosition;
const Parser = @import("parser.zig").Parser;
const Lexer = @import("lexer.zig").Lexer;
const Render = @import("render.zig");
const Allocator = std.mem.Allocator;
const Primitives = @import("ui/primitives.zig");
const Components = @import("ui/components.zig");
const UiState = @import("ui/state.zig").UiState;

fn getFontPath(allocator: Allocator) ![:0]u8 {
    const exe_path = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_path);

    const font_path = "../resources/fonts/IosevkaFixed-Regular.ttf";
    var paths = [_][]const u8 { exe_path, font_path };
    const full_font_path = try std.fs.path.join(allocator, &paths);
    defer allocator.free(full_font_path);

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.fs.realpath(full_font_path, &path_buf);
    return allocator.dupeZ(u8, path);
}

pub fn main() !void {
    rl.SetConfigFlags(rl.FLAG_WINDOW_HIGHDPI);
    rl.InitWindow(800, 600, "Fishtank");
    defer rl.CloseWindow();
    rl.SetTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        if (status != .ok) @panic("Memory leak detected!");
    }

    const dpi = rl.GetWindowScaleDPI();
    std.log.debug("DPI :.{any}", .{dpi});

    const font_path = try getFontPath(gpa.allocator());
    defer gpa.allocator().free(font_path);

    var ui = UiState{
        .text_config = .{
            .font = rl.LoadFont(font_path.ptr)
        },
    };
    defer rl.UnloadFont(ui.text_config.font.?);

    if (ui.text_config.font) |*font| {
        rl.GenTextureMipmaps(&font.texture);
        rl.SetTextureFilter(font.texture, rl.TEXTURE_FILTER_TRILINEAR);
    }

    const contents = try std.fs.cwd().readFileAlloc(
        gpa.allocator(),
        "test_subjects/core.clj",
        1024 * 1024 * 10,
    );
    defer gpa.allocator().free(contents);

    std.log.debug("Contents: \n {s}" ,.{contents});

    var lexer = Lexer.init(gpa.allocator(), contents);
    const tokens = try lexer.getTokens();
    defer tokens.deinit();

    var parser = Parser.init(gpa.allocator(), tokens.items);
    var module = try parser.parse("test_file.clj");
    defer module.deinit();

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(Primitives.bg_color);

        Components.screen(ui, 800, 600);
        Components.header(ui, 20, 100, "Module:");
        Components.label(ui, 100, 100, module.name);

        Components.header(ui, 20, 120, "Requires");
        for (module.required_modules.items, 0..) |req, idx| {
            const step = @as(i32, @intCast(idx * 20));
            Components.label(ui, 40, 140+step, req.name);

            if (req.as) |alias| {
                Components.label(ui, 40+170, 140 + step, "->");
                Components.label(ui, 40+200, 140 + step, alias);
            }
        }

        Components.header(ui, 20, 220, "Functions:");
        for (module.functions.items, 0..) |defn, idx| {
            const step = @as(i32, @intCast(idx * 20));
            Components.label(ui, 40, 240+step, defn.name);
        }
        rl.EndDrawing();
    }
}
