const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const token_module = @import("token.zig");
const Token = token_module.Token;
const TokenWithPosition = token_module.TokenWithPosition;
const Parser = @import("parser.zig").Parser;

const WIDTH: f32 = 200;
const HEIGHT: f32 = 150;
const TEXT_PADDING: f32 = 10;

const SHADOW_OFFSET: f32 = 4;
const shadow_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 40 };

pub fn main() !void {
    std.debug.print("Hello, world\n", .{});
    rl.InitWindow(800, 600, "Fishtank");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);



    const tokens = [_]TokenWithPosition{
        // (ns my-namespace)
        .{ .token = .LeftParen, .line = 1, .column = 1 },
        .{ .token = .{ .Symbol = "ns" }, .line = 1, .column = 2 },
        .{ .token = .{ .Symbol = "reagent.core" }, .line = 1, .column = 5 },
        .{ .token = .RightParen, .line = 1, .column = 16 },

        // (def x 42)
        .{ .token = .LeftParen, .line = 3, .column = 1 },
        .{ .token = .{ .Symbol = "def" }, .line = 3, .column = 2 },
        .{ .token = .{ .Symbol = "x" }, .line = 3, .column = 6 },
        .{ .token = .{ .Int = 42 }, .line = 3, .column = 8 },
        .{ .token = .RightParen, .line = 3, .column = 10 },

        .{ .token = .EOF, .line = 4, .column = 1 },
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        if (status != .ok) @panic("Memory leak detected!");
    }

    var parser = Parser.init(gpa.allocator(), &tokens);
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

        rl.DrawText(
            module.name.ptr,
            @as(i32, @intFromFloat(pos.x + TEXT_PADDING)),
            @as(i32, @intFromFloat(pos.y + TEXT_PADDING)),
            20,
            rl.BLACK
        );

        rl.EndDrawing();
    }
}
