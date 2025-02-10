const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const Module = @import("parser.zig").Module;

const WIDTH: f32 = 200;
const HEIGHT: f32 = 150;
const TEXT_PADDING: f32 = 10;

const SHADOW_OFFSET: f32 = 4;
const shadow_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 40 };


pub fn renderModule(module: Module) void {
    const pos = rl.Vector2{ .x = 100, .y = 100 };


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

}
