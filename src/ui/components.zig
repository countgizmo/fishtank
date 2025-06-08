const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const Primitives = @import("primitives.zig");
const Widget = Primitives.Widget;
const WidgetFlags = Primitives.WidgetFlags;
const Rect = Primitives.Rect;


pub fn screen(width: i32, height: i32) void {
    const widget = Widget{
        .rect = Rect{
            .x = 0,
            .y = 0,
            .width = @as(f32, @floatFromInt(width)),
            .height = @as(f32, @floatFromInt(height)),
        },
        .flags = .{
            .has_border = true
        },
    };

    Primitives.render_widget(widget);
}

pub fn label(x: i32, y: i32, text: [:0]const u8) void {
    var buf: [255:0] u8 = undefined;
    const label_text = std.fmt.bufPrintZ(&buf, "{s}", .{text}) catch "";

    const text_size = rl.MeasureTextEx(
        Primitives.text_config.font.?,
        label_text,
        Primitives.big_font_size,
        1);

    const label_x = @as(f32, @floatFromInt(x));
    const label_y = @as(f32, @floatFromInt(y));
    const widget = Widget{
        .rect = Rect{
            .x = label_x,
            .y = label_y,
            .width = text_size.x,
            .height = text_size.y
        },
        .text = text,
        .flags = .{
            .has_border = true,
            .has_text = true
        },
    };

    Primitives.render_widget(widget);
}
