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


pub fn main() !void {
    rl.InitWindow(800, 600, "Fishtank");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        if (status != .ok) @panic("Memory leak detected!");
    }

    var lexer = Lexer.init(gpa.allocator(), "(ns my-namespace (:require [clojure.string :as str]))");
    const tokens = try lexer.getTokens();
    defer tokens.deinit();


    var parser = Parser.init(gpa.allocator(), tokens.items);
    var module = try parser.parse("test_file.clj");
    defer module.deinit();


    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.WHITE);

        Render.renderModule(module);
        rl.EndDrawing();
    }
}
