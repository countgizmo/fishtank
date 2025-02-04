const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const token_module = @import("token.zig");
const Token = token_module.Token;
const TokenWithPosition = token_module.TokenWithPosition;
const Parser = @import("parser.zig").Parser;
const Lexer = @import("lexer.zig").Lexer;

const WIDTH: f32 = 200;
const HEIGHT: f32 = 150;
const TEXT_PADDING: f32 = 10;

const SHADOW_OFFSET: f32 = 4;
const shadow_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 40 };

pub fn main() !void {
    rl.InitWindow(800, 600, "Fishtank");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        if (status != .ok) @panic("Memory leak detected!");
    }

    var lexer = Lexer.init(gpa.allocator(), "(ns reagent.core)");
    const tokens = try lexer.getTokens();
    defer tokens.deinit();


    var parser = Parser.init(gpa.allocator(), tokens.items);
    var module = try parser.parse("test_file.clj");
    defer module.deinit();

    const pos = rl.Vector2{ .x = 100, .y = 100 };

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.WHITE);

        rl.DrawRectangle(
            @as(i32, @intFromFloat(pos.x + SHADOW_OFFSET)),
            @as(i32, @intFromFloat(pos.y + SHADOW_OFFSET)),
            @as(i32, WIDTH),
            @as(i32, HEIGHT),
            shadow_color
        );

        // Main rectangle (white fill with black outline)
        rl.DrawRectangle(
            @as(i32, @intFromFloat(pos.x)),
            @as(i32, @intFromFloat(pos.y)),
            @as(i32, WIDTH),
            @as(i32, HEIGHT),
            rl.WHITE
        );

        rl.DrawRectangleLines(
            @as(i32, @intFromFloat(pos.x)),
            @as(i32, @intFromFloat(pos.y)),
            @as(i32, WIDTH),
            @as(i32, HEIGHT),
            rl.BLACK
        );

        var buf: [255:0] u8 = undefined;
        const module_name = std.fmt.bufPrintZ(&buf, "{s}", .{module.name}) catch "";

        rl.DrawText(
            module_name,
            @as(i32, @intFromFloat(pos.x + TEXT_PADDING)),
            @as(i32, @intFromFloat(pos.y + TEXT_PADDING)),
            20,
            rl.BLACK
        );

        rl.EndDrawing();
    }
}
