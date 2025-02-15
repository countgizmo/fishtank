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

    // Draw requires
    var y_offset: f32 = PADDING * 2 + LINE_HEIGHT;

    // Draw "requires:" label
    if (module.required_modules.items.len > 0) {
        rl.DrawText(
            "requires:",
            @as(i32, @intFromFloat(pos.x + TEXT_PADDING)),
            @as(i32, @intFromFloat(pos.y + y_offset)),
            16,
            rl.GRAY
        );

        y_offset += LINE_HEIGHT;
    }

    // Draw each required library
    for (module.required_modules.items) |entry| {
        const lib_name = std.fmt.bufPrintZ(&buf, "{s}", .{entry.name}) catch "";

        const x = @as(i32, @intFromFloat(pos.x + 2*TEXT_PADDING));
        const y = @as(i32, @intFromFloat(pos.y + y_offset));
        rl.DrawText(
            lib_name,
            x,
            y,
            16,
            rl.BLACK
        );

        if (entry.as) |alias| {
            const lib_as = std.fmt.bufPrintZ(&buf, " {s}", .{alias}) catch "";
            const lib_name_size = rl.MeasureTextEx(rl.GetFontDefault(), entry.name.ptr, 16, 0);
            const lib_as_x = x + @as(i32, @intFromFloat(lib_name_size.x));

            rl.DrawText(
                lib_as,
                lib_as_x,
                y,
                16,
                rl.BLUE
            );

        }

        // const = std.fmt.bufPrintZ(&buf, "{s}", .{module.name}) catch "";
        // // Draw alias in parentheses if it's different from the last part of the namespace
        // if (!std.mem.eql(u8, alias, full_name)) {
        //     var alias_text = std.fmt.allocPrint(
        //     self.module.allocator,
        //     "({s})",
        //     .{alias}
        // ) catch continue;
        //     defer self.module.allocator.free(alias_text);
        //
        //     ray.DrawText(
        //     alias_text.ptr,
        //     @as(i32, @intFromFloat(pos.x + PADDING + 8 * @as(f32, @floatFromInt(full_name.len)))),
        //     @as(i32, @intFromFloat(pos.y + y_offset)),
        //     16,
        //     Color.gray
        // );
        // }

        y_offset += LINE_HEIGHT;
    }
}
