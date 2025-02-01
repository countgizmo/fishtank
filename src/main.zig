const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});


pub fn main() void {
    std.debug.print("Hello, world\n", .{});
    rl.InitWindow(800, 600, "Fishtank");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(rl.PINK);
        rl.DrawText("Hello, Fishtank", 190, 200, 20, rl.BLUE);
        rl.EndDrawing();
    }
}
