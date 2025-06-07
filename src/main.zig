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
    var font = rl.LoadFont(font_path.ptr);
    defer rl.UnloadFont(font);

    rl.GenTextureMipmaps(&font.texture);
    rl.SetTextureFilter(font.texture, rl.TEXTURE_FILTER_BILINEAR);

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

        Render.renderModule(font, module);
        rl.EndDrawing();
    }
}
