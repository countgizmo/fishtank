const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const Module = @import("parser.zig").Module;

const WIDTH: f32 = 400;
const HEIGHT: f32 = 200;
const TEXT_PADDING: f32 = 10;
const PADDING: f32 = 10;
const LINE_HEIGHT: f32 = 20;

const SHADOW_OFFSET: f32 = 4;
const shadow_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 40 };

pub fn renderModule(font: rl.Font, module: Module) void {
    const pos = rl.Vector2{ .x = 100, .y = 100 };

    // Shadow
    rl.DrawRectangle(
        @as(i32, @intFromFloat(pos.x + SHADOW_OFFSET)),
        @as(i32, @intFromFloat(pos.y + SHADOW_OFFSET)),
        @as(i32, WIDTH),
        @as(i32, HEIGHT),
        shadow_color
    );

    // Card
    rl.DrawRectangle(
        @as(i32, @intFromFloat(pos.x)),
        @as(i32, @intFromFloat(pos.y)),
        @as(i32, WIDTH),
        @as(i32, HEIGHT),
        rl.WHITE
    );

    // Border
    rl.DrawRectangleLines(
        @as(i32, @intFromFloat(pos.x)),
        @as(i32, @intFromFloat(pos.y)),
        @as(i32, WIDTH),
        @as(i32, HEIGHT),
        rl.BLACK
    );

    // Draw the name
    var buf: [255:0] u8 = undefined;
    const module_name = std.fmt.bufPrintZ(&buf, "{s}", .{module.name}) catch "";
    const name_pos = rl.Vector2 {
        .x = @as(i32, @intFromFloat(pos.x + TEXT_PADDING)),
        .y = @as(i32, @intFromFloat(pos.y + TEXT_PADDING)),
    };
    rl.DrawTextEx(
        font,
        module_name,
        name_pos,
        20,
        0,
        rl.BLACK
    );

    // Draw requires
    var y_offset: f32 = PADDING * 2 + LINE_HEIGHT;

    // Draw "requires:" label
    if (module.required_modules.items.len > 0) {
        const req_position = rl.Vector2 {
            .x = pos.x + TEXT_PADDING,
            .y = pos.y + y_offset,
        };

        rl.DrawTextEx(
            font,
            "requires:",
            req_position,
            16,
            0,
            rl.GRAY
        );

        y_offset += LINE_HEIGHT;
    }

    // Draw each required library
    for (module.required_modules.items) |entry| {
        const lib_name = std.fmt.bufPrintZ(&buf, "{s}", .{entry.name}) catch "";

        const lib_name_pos = rl.Vector2 {
            .x = pos.x + 2*TEXT_PADDING,
            .y = pos.y + y_offset,
        };

        rl.DrawTextEx(
            font,
            lib_name,
            lib_name_pos,
            16,
            0,
            rl.BLACK
        );

        if (entry.as) |alias| {
            const lib_as = std.fmt.bufPrintZ(&buf, " {s}", .{alias}) catch "";
            const lib_name_size = rl.MeasureTextEx(rl.GetFontDefault(), entry.name.ptr, 16, 0);
            const lib_pos = rl.Vector2 {
                .x = lib_name_pos.x + lib_name_size.x,
                .y = lib_name_pos.y,
            };

            rl.DrawTextEx(
                font,
                lib_as,
                lib_pos,
                16,
                0,
                rl.BLUE
            );
        }

        y_offset += LINE_HEIGHT;
    }
}
